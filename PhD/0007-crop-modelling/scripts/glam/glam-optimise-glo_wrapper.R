#Julian Ramirez-Villegas
#UoL / CCAFS / CIAT
#June 2012


glam_optimise_glo_wrapper <- function(this_run) {
  
  #get the run details
  sid <- runs_ref$SID[this_run]
  run <- runs_ref$RUN[this_run]
  seed <- runs_ref$SEED[this_run]
  expID <- runs_ref$EXPID[this_run]
  
  
  #check the existence of three parameters needed for sourcing this script
  if (class(try(get("src.dir"),silent=T)) == "try-error") {
    stop("src.dir needs to be set")
  }
  
  if (class(try(get("bDir"),silent=T)) == "try-error") {
    stop("bDir needs to be set")
  }
  
  if (class(try(get("expID"),silent=T)) == "try-error") {
    stop("ID of experiment needs to be set")
  }
  
  if (class(try(get("run"),silent=T)) == "try-error") {
    stop("run needs to be set")
  }
  
  if (class(try(get("version"),silent=T)) == "try-error") {
    stop("version of gridcell selection needs to be provided: a, b...")
  }
  
  if (class(try(get("maxiter"),silent=T)) == "try-error") {
    stop("maxiter (max. num. iterations) needs to be set")
  }
  
  
  #Read in a dummy GLAM parameter file and create a new one based on a new parameter for
  #running and optimising GLAM
  
  #source all needed functions
  source(paste(src.dir,"/glam/glam-parFile-functions.R",sep=""))
  source(paste(src.dir,"/glam/glam-soil-functions.R",sep=""))
  source(paste(src.dir,"/glam/glam-runfiles-functions.R",sep=""))
  source(paste(src.dir,"/glam/glam-soil-functions.R",sep=""))
  source(paste(src.dir,"/glam/glam-make_wth.R",sep=""))
  source(paste(src.dir,"/glam/glam-optimise-functions.R",sep=""))
  source(paste(src.dir,"/signals/climateSignals-functions.R",sep=""))
  
  
  #input directories and model
  cropName <- "gnut"
  cDir <- paste(bDir,"/model-runs/",toupper(cropName),sep="")
  pDir <- paste(cDir,"/params",sep="") #parameter files
  
  
  #load list of parameters to optimise, ranges, and number of steps, randomise
  opt_rules <- read.table(paste(pDir,"/optimisation-rules.txt",sep=""),sep="\t",header=T)
  
  if (!is.na(seed)) {
    set.seed(seed)
    reord <- sample(1:nrow(opt_rules),replace=F)
    opt_rules <- opt_rules[reord,]
    row.names(opt_rules) <- 1:nrow(opt_rules)
  }
  
  
  #load cell details
  cells <- read.csv(paste(cDir,"/inputs/calib-cells-selection-",selection,".csv",sep=""))
  
  #load runs to perform
  all_runs <- read.table(paste(cDir,"/calib/optim_zones.txt",sep=""),header=T,sep="\t")
  
  
  #get run setup
  #files that were generated
  setup <- list()
  setup$BDIR <- bDir
  setup$ZONE <- all_runs$zone[run]
  setup$NUM_CELLS <- length(cells$CELL[which(cells$ISSEL_F == 1 & cells$ZONE == setup$ZONE)])
  setup$METHOD <- "lin"
  setup$CROPNAME <- "gnut"
  setup$CAL_DIR <- paste(setup$BDIR,"/model-runs/",toupper(setup$CROPNAME),"/calib/exp-",expID,sep="")
  setup$YIELD_FILE <- paste(cDir,"/inputs/ascii/obs/yield_calz",setup$ZONE,version,"_",setup$METHOD,".txt",sep="")
  setup$YGP_FILE <- "nofile"
  setup$SOW_FILE_RFD <- paste(cDir,"/inputs/ascii/sow/sowing_calz",setup$ZONE,version,"_start.txt",sep="")
  setup$SOW_FILE_IRR <- paste(cDir,"/inputs/ascii/sow/sowing_calz",setup$ZONE,version,"_irr.txt",sep="")
  setup$WTH_DIR_RFD <- paste(cDir,"/inputs/ascii/wth/rfd_calz",setup$ZONE,version,sep="")
  setup$WTH_DIR_IRR <- paste(cDir,"/inputs/ascii/wth/irr_calz",setup$ZONE,version,sep="")
  setup$WTH_ROOT <- "ingc"
  setup$SOL_FILE <- paste(cDir,"/inputs/ascii/soil/soiltypes_calz",setup$ZONE,version,".txt",sep="")
  setup$SOL_GRID <- paste(cDir,"/inputs/ascii/soil/soilcodes_calz",setup$ZONE,version,".txt",sep="")
  setup$SIM_NAME <- paste(all_runs$run_name[run]) 
  
  #get defaults (parameter set)
  params <- GLAM_get_default(x=cells,cell=NA,parDir=pDir)
  params$glam_param.mod_mgt$ISYR <- 1966 #start year
  params$glam_param.mod_mgt$IEYR <- 1993 #end year
  params$glam_param.mod_mgt$IASCII <- 1 #output only to .out file
  params$glam_param.sim_ctr$NDSLA <- 1
  
  #if there is a ygp file then add it to the run setup
  if (use_ygp) {
    setup$YGP_FILE <- paste(cDir,"/inputs/ascii/ygp/ygp_calz",setup$ZONE,version,".txt",sep="")
    params$glam_param.ygp$YGP$Value <- -99.0
  }
  
  #extract irrigation rates for selected gridcells
  irDir <- paste(cDir,"/irrigated_ratio",sep="")
  library(raster)
  ir_stk <- stack(paste(irDir,"/raw-",1966:1993,".asc",sep=""))
  ir_vls <- extract(ir_stk,cbind(X=cells$X[which(cells$ZONE==setup$ZONE & cells$ISSEL_F == 1)],
                                 Y=cells$Y[which(cells$ZONE==setup$ZONE & cells$ISSEL_F == 1)]))
  sc <- cells$CELL[which(cells$ZONE==setup$ZONE & cells$ISSEL_F == 1)]
  
  col <- 0; row <- 1
  for (nc in 1:length(sc)) {
    if (col == 10) {
      col <- 1
      row <- row+1
    } else {
      col <- col+1
    }
    
    cll <- sc[nc]
    cl_vls <- as.numeric(ir_vls[nc,])
    cl_vls <- data.frame(CELL=cll,ROW=row,COL=col,YEAR=1966:1993,IRATIO=cl_vls)
    
    if (nc == 1) {
      all_cll <- cl_vls
    } else {
      all_cll <- rbind(all_cll,cl_vls)
    }
  }
  
  all_cll$IRATIO[which(all_cll$IRATIO > 1)] <- 1
  ir_vls <- all_cll
  
  
  #now the optimisation routine
  optimised <- list()
  optimal <- list()
  
  
  #now do the various iterations to look for the optimal parameter set
  if (!file.exists(paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/calib.csv",sep=""))) {
    #do various iterations to test for local minima
    for (itr in 1:maxiter) {
      setwd(cDir)
      for (rw in 1:nrow(opt_rules)) {
        parname <- paste(opt_rules$param[rw])
        where <- paste(opt_rules$sect[rw])
        nstep <- opt_rules$n.steps[rw]
        
        cat("\ncalibrating",parname,"using",nstep,"steps\n")
        
        #run the optimisation routine for any system system
        optimised[[parname]] <- GLAM_optimise_glo(GLAM_params=params,RUN_setup=setup,sect=where,
                                                  param=parname,n.steps=nstep,iter=itr,iratio=ir_vls)
        
        
        #plot(optimised[[parname]]$VALUE,optimised[[parname]]$RMSE,ty="l",xlab="Parameter value",ylab="RMSE (kg/ha)",main=parname)
        optimal[[parname]] <- optimised[[parname]]$VALUE[which(optimised[[parname]]$RMSE == min(optimised[[parname]]$RMSE))]
        cat(parname,":",optimal[[parname]],"\n")
        if (length(optimal[[parname]]) > 1) {optimal[[parname]] <- optimal[[parname]][round(length(optimal[[parname]])/2,0)]}
        
        #updating parameter set
        if (parname == "TO" | parname == "TB" | parname == "TM") {
          params[[where]][[paste(parname,"FLWR",sep="")]]$Value <- optimal[[parname]]
          params[[where]][[paste(parname,"PODF",sep="")]]$Value <- optimal[[parname]]
          params[[where]][[paste(parname,"LMAX",sep="")]]$Value <- optimal[[parname]]
          params[[where]][[paste(parname,"HARV",sep="")]]$Value <- optimal[[parname]]
        } else {
          params[[where]][[parname]]$Value <- optimal[[parname]]
        }
        
        #comprising everything into a single table
        out_param <- data.frame(iter=itr,param=parname,sect=where,n.step=nstep,
                                opt_val=optimal[[parname]],
                                min_rmse=min(optimised[[parname]]$RMSE),
                                max_rmse=max(optimised[[parname]]$RMSE))
        if (rw == 1) {
          out_glam <- out_param
        } else {
          out_glam <- rbind(out_glam,out_param)
        }
      }
      
      save(list=c("optimised","optimal"),file=paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/iter-",itr,"/output.RData",sep=""))
      
      #store all iterations in one matrix
      if (itr == 1) {
        out_itr <- out_glam
      } else {
        out_itr <- rbind(out_itr,out_glam)
      }
      
    }
    write.csv(out_itr,paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/calib.csv",sep=""),quote=T,row.names=F)
  }
  
  
  
  #################################################################################
  ##make plots of each parameter tuning
  if (plot_all) {
    cal_data <- read.csv(paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/calib.csv",sep=""))
    optimal <- cal_data[which(cal_data$iter==maxiter),]
    par_list <- c(paste(optimal$param))
    iter <- c(rep(maxiter,times=nrow(optimal)))
    pList <- data.frame(param=par_list,iter=iter)
    
    plotsDir <- paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/plots",sep="")
    if (!file.exists(plotsDir)) {dir.create(plotsDir)}
    
    for (rw in 1:nrow(pList)) {
      pname <- paste(pList$param[rw])
      iter <- paste(pList$iter[rw])
      
      #load the workspace
      load(paste(setup$CAL_DIR,"/",setup$SIM_NAME,"/iter-",iter,"/output.RData",sep=""))
      
      #now make the plot
      tiff(paste(plotsDir,"/",tolower(pname),".tif",sep=""),res=300,compression="lzw",height=1000,
           width=1250,pointsize=8)
      par(mar=c(3,3,2,1))
      plot(optimised[[pname]]$VALUE,optimised[[pname]]$RMSE,ty="l",
           main=paste(pname," :: ",optimal[[pname]],sep=""),
           xlab="Parameter value",ylab="RMSE (kg/ha)")
      grid(nx=10,ny=10)
      abline(v=optimal[[pname]],col="red",lty=2,lwd=0.8)
      dev.off()
    }
  }
}


