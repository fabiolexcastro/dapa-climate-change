#JRV 2013
#CIAT / CCAFS

############################################################
### functions to fit models using BIOMOD2 library
############################################################

#function to run a model with provided configuration
run_bias_model <- function(bDir,sppName,npa,alg,model_class="model_fit") {
  require(biomod2); require(raster); require(rgdal); require(maptools); require(dismo)
  
  #i/o dirs
  maxDir <- paste(bDir,"/bin",sep="")
  dataDir <- paste(bDir,"/occurrences",sep="")
  modDir <- paste(bDir,"/samplebias",sep="")
  bgDir <- paste(bDir,"/bg-areas",sep="")
  envDir <- paste(bDir,"/env-data",sep="")
  topDir <- paste(envDir,"/topography",sep="")
  accDir <- paste(envDir,"/access_50k",sep="")
  if (!file.exists(modDir)) {dir.create(modDir)}
  
  #genus name
  genName <- unlist(strsplit(sppName,"_",fixed=T))[1]
  
  #1. output model and config directory
  cat("loading presence and pseudo-absence data\n")
  outDir <- paste(modDir,"/",alg,"/PA-",npa,sep="")
  if (!file.exists(outDir)) {dir.create(outDir,recursive=T)}
  
  #2. load species data (from occurrences dir)
  if (!file.exists(paste(dataDir,"/",genName,"_sbias_occ.csv",sep=""))) {
    spp_data <- read.csv(paste(dataDir,"/",genName,".txt",sep=""))
    spp_data <- spp_data[,c("ID","LONGITUDE","LATITUDE")]
    
    #extract env data for spp data
    spp_data <- unique(spp_data[,2:3])
    rs <- raster(paste(accDir,"/access.tif",sep=""))
    spp_data <- cbind(spp_data,access=extract(rs,spp_data[,c("LONGITUDE","LATITUDE")]))
    rm(rs); g=gc(); rm(g)
    rs <- stack(paste(topDir,"/",c("slope","aspect"),".tif",sep=""))
    spp_data <- cbind(spp_data,extract(rs,spp_data[,c("LONGITUDE","LATITUDE")]))
    rm(rs); g=gc(); rm(g)
    spp_data$slope <- spp_data$slope * 100
    spp_data$NAS <- apply(spp_data,1,FUN=function(x) {length(which(is.na(x)))})
    spp_data <- spp_data[which(spp_data$NAS == 0),]
    spp_data$NAS <- NULL #removes field NAS
    rownames(spp_data) <- 1:nrow(spp_data)
    write.csv(spp_data,paste(dataDir,"/",genName,"_sbias_occ.csv",sep=""),quote=T,row.names=F)
  } else {
    spp_data <- read.csv(paste(dataDir,"/",genName,"_sbias_occ.csv",sep=""))
  }
  
  #3. load background data / create if needs be
  pab_data <- get_pa_sbias(spp_name=sppName,spp_data=spp_data,n_pa=npa,bg_dir=bgDir,
                           topo_dir=topDir,acc_dir=accDir)
  
  #put interactions into data frames
  cat("making interactions\n")
  spp_data$access2 <- spp_data$access ^ 2; spp_data$access3 <- spp_data$access ^ 3
  spp_data$slope2 <- spp_data$slope ^ 2; spp_data$slope3 <- spp_data$slope ^ 3
  spp_data$aspect2 <- spp_data$aspect ^ 2; spp_data$aspect3 <- spp_data$aspect ^ 3
  spp_data$access_slope <- spp_data$access * spp_data$slope
  spp_data$access_aspect <- spp_data$access * spp_data$aspect
  spp_data$aspect_slope <- spp_data$slope * spp_data$aspect
  spp_data$access_aspect_slope <- spp_data$access * spp_data$slope * spp_data$aspect
  
  pab_data$access2 <- pab_data$access ^ 2; pab_data$access3 <- pab_data$access ^ 3
  pab_data$slope2 <- pab_data$slope ^ 2; pab_data$slope3 <- pab_data$slope ^ 3
  pab_data$aspect2 <- pab_data$aspect ^ 2; pab_data$aspect3 <- pab_data$aspect ^ 3
  pab_data$access_slope <- pab_data$access * pab_data$slope
  pab_data$access_aspect <- pab_data$access * pab_data$aspect
  pab_data$aspect_slope <- pab_data$slope * pab_data$aspect
  pab_data$access_aspect_slope <- pab_data$access * pab_data$slope * pab_data$aspect
  
  #run only if final stored objects do not exist
  if (!file.exists(paste(outDir,"/",gsub("\\_","\\.",genName),"/fitting.RData",sep=""))) {
    cat("\n-------------------------------------------------------\n")
    cat("---- processing genus", genName,"\n")
    cat("-------------------------------------------------------\n")
    
    spp_tr <- spp_data; names(spp_tr)[1:2] <- c("x","y")
    pab_tr <- pab_data
    
    #5. Model fitting
    #go to models directory
    setwd(outDir)
    
    #training: 
    #explanatory variables have to contain the pseudo-absence data AND the presence data
    #make occurrences into appropriate format (vector resp_var)
    cat("configuring input data and model parameters\n")
    expl_var <- rbind(spp_tr,pab_tr)
    expl_var <- SpatialPointsDataFrame(coords=cbind(expl_var$x,expl_var$y),data=expl_var[,3:ncol(expl_var)])
    resp_var <- c(rep(1,times=nrow(spp_tr)),rep(NA,times=nrow(pab_tr)))
    
    #formatting data
    sp_bData <- BIOMOD_FormatingData(resp.var = resp_var,expl.var = expl_var, 
                                     resp.xy=coordinates(expl_var),
                                     resp.name = genName, 
                                     PA.strategy="random",
                                     PA.nb.rep=1,PA.nb.absences=10000)
    
    #selecting model features (!change features as needed)
    sp_mOpt <- BIOMOD_ModelingOptions()
    sp_mOpt@MAXENT$path_to_maxent.jar <- maxDir
    sp_mOpt@MAXENT$maximumiterations <- 1000
    sp_mOpt@MAXENT$quadratic <- F
    sp_mOpt@MAXENT$product <- F
    sp_mOpt@MAXENT$threshold <- F
    sp_mOpt@MAXENT$hinge <- F
    sp_mOpt@GBM$n.trees <- 2000
    sp_mOpt@GLM$type <- "simple" #simple | quadratic | polynomial
    sp_mOpt@GLM$control$maxit <- 100
    sp_mOpt@GAM$k <- 3
    sp_mOpt@RF$ntree <- 100
    
    #perform the modelling
    out_obj <- paste(outDir,"/",sp_bData@sp.name,"/",sp_bData@sp.name,".",model_class,".models.out",sep="")
    
    #note that the biomod output is simply a linear scaling from 0 to 1000!!
    cat("running model\n")
    if (!file.exists(out_obj)) {
      sp_mOut <- BIOMOD_Modeling(sp_bData,
                                 models = alg,
                                 models.options = sp_mOpt,
                                 NbRunEval=1,
                                 DataSplit=100,
                                 Prevalence=0.5,
                                 VarImport=10,
                                 models.eval.meth = c('KAPPA','TSS','ROC'),
                                 SaveObj = TRUE,
                                 rescal.all.models = TRUE,
                                 do.full.models = FALSE,
                                 modeling.id = model_class)
    } else {
      sp_mOut <- get(load(out_obj)) #load model as it already exists
    }
    
    #save object with all necessary details
    cat("saving final objects\n")
    save(list=c("sp_bData","sp_mOut"),file=paste(outDir,"/",sp_bData@sp.name,"/fitting.RData",sep=""))
    
    #go back to base directory
    setwd(bDir)
  }
  #return object
  return(outDir)
}


### function to get a given number of pseudo-absences (with env data)
get_pa_sbias <- function(spp_name,spp_data,n_pa,bg_dir,topo_dir,acc_dir) {
  #check existence
  gen_name <- unlist(strsplit(spp_name,"_",fixed=T))[1]
  
  if (!file.exists(paste(bg_dir,"/",spp_name,"/sbias_bg_",n_pa,".RData",sep=""))) {
    cat("pseudo-absences don't exist yet, drawing pseudo absences",n_pa,"\n")
    #background area loading / creation
    bg_df <- load_bg_sbias(spp_name,bg_dir,topo_dir,acc_dir)
    
    #select PA from bg_df (without defining seed)
    cat("sampling\n")
    set.seed(n_pa); pa_sel <- sample(1:nrow(bg_df),11000)
    bg_sel <- bg_df[pa_sel,]; rm(bg_df); g=gc(); rm(g)
    rownames(bg_sel) <- 1:nrow(bg_sel)
    
    #5. extract climate data for pseudo absences
    cat("extracting climate\n")
    acc_stk <- stack(c(paste(acc_dir,"/access.tif",sep="")))
    bg_data <- as.data.frame(extract(acc_stk,bg_sel))
    bg_data <- cbind(bg_sel,bg_data)
    
    #extract topography data
    cat("extracting topography\n")
    top_stk <- stack(paste(topo_dir,"/",c("aspect.tif","slope.tif"),sep=""))
    bg_data <- cbind(bg_data,as.data.frame(extract(top_stk,bg_sel))) #for pa
    bg_data$slope <- bg_data$slope * 100
    
    #check missing
    cat("final checks\n")
    bg_data$NAs <- apply(bg_data,1,FUN=function(x) {nac <- length(which(is.na(x))); return(nac)})
    bg_data <- bg_data[which(bg_data$NAs == 0),]
    bg_data$NAs <- NULL
    bg_data <- bg_data[1:10000,]
    rownames(bg_data) <- 1:nrow(bg_data)
    
    #write both objects into RData file
    cat("saving...\n")
    write.csv(bg_data,paste(bg_dir,"/",spp_name,"/sbias_bg_",n_pa,".csv",sep=""),row.names=F,quote=T)
    save(list=c("bg_data"),file=paste(bg_dir,"/",spp_name,"/sbias_bg_",n_pa,".RData",sep=""))
  } else {
    cat("pseudo-absences did exist, loading...\n")
    load(file=paste(bg_dir,"/",spp_name,"/sbias_bg_",n_pa,".RData",sep=""))
  }
  return(bg_data)
}


#### load background area / create if doesnt exist
load_bg_sbias <- function(spp_name,back_dir,topo_dir,acc_dir) {
  #filename
  bg_file <- paste(back_dir,"/",spp_name,"/",spp_name,"_sbias_bg.RData",sep="")
  if (!file.exists(bg_file)) {
    cat("creating background area as it didn't exist\n")
    
    #load verification files
    msk <- raster(paste(acc_dir,"/access.tif",sep=""))
    other_rs <- c(paste(topo_dir,"/aspect.tif",sep=""),
                  paste(topo_dir,"/slope.tif",sep=""))
    
    #rasterize the shapefile
    if (!file.exists(paste(back_dir,"/",spp_name,"/",spp_name,".tif",sep=""))) {
      cat("rasterize\n")
      #check existence of shapefile
      bg_sh <- paste(back_dir,"/",spp_name,"/",spp_name,".shp",sep="")
      if (!file.exists(bg_sh)) {stop("shapefile does not exist, please check")}
      #load input shapefile and mask
      bg_sh <- readShapePoly(bg_sh)
      #rasterize
      bg_rs <- rasterize(bg_sh,msk,silent=T,filename=paste(back_dir,"/",spp_name,"/",spp_name,".tif",sep=""),format="GTiff")
    } else {
      cat("load raster\n")
      bg_rs <- raster(paste(back_dir,"/",spp_name,"/",spp_name,".tif",sep=""))
    }
    
    #get xy from bg
    cat("make data frame\n")
    bg_rs[which(!is.na(bg_rs[]))] <- 1
    bg_df <- as.data.frame(xyFromCell(bg_rs,which(!is.na(bg_rs[]))))
    
    #removing grid cells that are NA
    cat("remove NAs from access\n")
    msk <- readAll(msk); rm(bg_rs); g=gc(); rm(g)
    bg_df$value <- extract(msk,cbind(x=bg_df$x,y=bg_df$y))
    bg_df <- bg_df[which(!is.na(bg_df$value)),]
    rm(msk); g=gc(); rm(g)
    bg_df$value <- NULL
    
    for (ors in other_rs) {
      cat("remove NAs from",ors,"\n")
      msk <- raster(ors); msk <- readAll(msk)
      bg_df$value <- extract(msk,cbind(x=bg_df$x,y=bg_df$y))
      bg_df <- bg_df[which(!is.na(bg_df$value)),]
      bg_df$value <- NULL
      rm(msk); g=gc(); rm(g)
    }
    
    #save object
    cat("saving...\n")
    save(list=c("bg_df"),file=bg_file)
  } else {
    cat("loading background area as it did exist\n")
    load(bg_file)
  }
  return(bg_df)
}

