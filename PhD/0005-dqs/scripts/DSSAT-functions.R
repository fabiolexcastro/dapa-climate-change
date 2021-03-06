#Julian Ramirez-Villegas
#November 2011
#CIAT / CCAFS / UoL

#This script will source the functions and basic variables, and needs to be sourced
#before each CROPGRO model run

####### WORKFLOW
#1. Create soil file (soil.sol) by modifying the existing one, and using a new SLPF, 
#   use step, max and min as arguments
#
#2. Go to C:\DSSAT45\Peanut folder and run the following line
#    C:\DSSAT45\DSCSM045.EXE CRGRO045 B DSSBatch.v45
#   This would use only one treatment assigned to the soil file soil.sol and will run the crop model
#
#3. Read Summary.out in the Peanut folder and get the 'HWAH', compare this with the observed yield. 
#     a. Calculate RMSE
#     b. Calculate correlation coefficient
#   Store both in a file for further analysis, flagging the minimum RMSE
#
#4. To perform runs with other weather data, remove existing weather files from 
#   D:\CIAT_work\GLAM\PNAS-paper\DSSAT-PNUT\GJ-weather\WTH and put new files into that folder.
#   Then perform again from (1) to (3) and keep files for further analysis

########################################################################################
########## FUNCTIONS TO OPTIMISE BASED ON SHUFFLED OR PERTURBED YIELD DATA
########################################################################################
#1. Remove the data from ./DSSAT-PNUT/GJ-weather/WTH
#2. Copy the perturbed/shuffled data into that folder
#3. Call the CROPGRO wrapper and assess the model
#
#   Note: use p, s, variable as function arguments to find the folder
#         where the model is run
#

#Base calculation directory (for his to work the folder structure must be maintained)
#bd <- "D:/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT" #windows
#bd <- "/media/DATA/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT" #linux

#This is a function for creating the experiment matrix, used only for testing purposes
createExpMat <- function(bDir) {
  experiments <- list.files(paste(bDir,"/GJ-weather/shuf-pert",sep=""))
  type <- substr(experiments,1,1)
  position <- gregexpr("_",experiments)
  for (ex in 1:length(experiments)) {
    v <- substr(experiments[ex],position[[ex]][1]+1,position[[ex]][2]-1)
    k <- substr(experiments[ex],position[[ex]][2]+1,nchar(experiments[ex]))
    if (ex==1) {variable <- v;scale<-k} else {variable <- c(variable,v);scale<-c(scale,k)}
  }
  experiments <- data.frame(TYPE=type,VAR=variable,SCALE=scale)
  return(experiments)
}

#################################################################################
#Function for creating control files (do this before running any perturbed/shuffled experiment)
#create a data frame with all seeds and perturbations, this will be used as control file.
createControlFiles <- function(bDir) {
  experiments <- createExpMat(bDir)
  for (i in 1:nrow(experiments)) {
    ty <- experiments$TYPE[i]
    va <- experiments$VAR[i]
    sc <- experiments$SCALE[i]
    if (!file.exists(paste(bDir,"/bin/control/",ty,"_",va,"_",sc,".csv",sep=""))) {
      dataFol <- paste(bDir,"/GJ-weather/shuf-pert/",ty,"_",va,"_",sc,sep="")
      fList <- list.files(dataFol)
      for (f in fList) {
        cat(paste(ty),paste(va),paste(sc),paste(f),"\n")
        if (ty=="p") {
          sep <- unlist(strsplit(f,"_",fixed=T))
          p <- as.numeric(gsub("p-","",sep[1]))
          s <- as.numeric(gsub("s-","",sep[2]))
        } else {
          p <- NA
          s <- as.numeric(gsub("s-","",f))
        }
        outrow <- data.frame(TYPE=ty,VAR=va,SCALE=sc,P=p,SEED=s)
        if (f==fList[1]) {
          outMat <- outrow
        } else {
          outMat <- rbind(outrow,outMat)
        }
      }
      write.csv(outMat,paste(bDir,"/bin/control/",ty,"_",va,"_",sc,".csv",sep=""),row.names=F,quote=F)
    }
  }
}


####################
#################### BELOW IS A TESTING EXPERIMENT TO SEE WHAT HAPPENS #############
#x is experiment
testParallel <- function(bDir,x=1) {
  experiments <- createExpMat(bDir)
  spIn <- paste(bDir,"/GJ-weather/shuf-pert/",experiments$TYPE[x],"_",experiments$VAR[x],"_",experiments$SCALE[x],sep="") #folder where S|P occur
  
  if (experiments$TYPE[x]=="p") { #create list of perturbing values
    p_list <- seq(0,299,by=1)
    s_list <- list.files(spIn,pattern="p-0_s-")
    s_list <- as.numeric(gsub("p-0_s-","",s_list))
  } else {
    p_list <- NA
    s_list <- list.files(spIn,pattern="s-")
    s_list <- as.numeric(gsub("s-","",s_list))
  }
  if (!is.na(p_list[1])) {p <- p_list[1]} else {p <- NA} #define perturb ratio
  s <- s_list[1] #define seed
  
  #run model
  opt_ps <- runPSModel(bDir,ty=experiments$TYPE[x],v=experiments$VAR[x],sc=experiments$SCALE[x],s=s,p=p)
  opt_ps <- runPSModel(bDir,ty="p",v="prec",sc="climate",s=997,p=99)
  
  #parallelise
  #initialise
  library(snowfall)
  sfInit(parallel=T,cpus=3)
  
  #export functions
  sfExport("accuracy")
  sfExport("optSLPF")
  sfExport("runCROPGRO"); sfExport("runCROPGROPS")
  sfExport("runPSModel")
  sfExport("writeSoilFile")
  
  #testing mode
  p_list <- p_list[1:3]
  sfExport("bDir"); sfExport("p_list"); sfExport("s_list"); sfExport("x"); sfExport("experiments")
  
  #here i need to create a function that makes use of a data.frame in which
  #the p and s values are specified for each experiment configuration so that this thing
  #can be run in parallel. Some type of progress track needs to be implemented, likely
  #via a file that is appended
  system.time(sfSapply(p_list, function(i) 
    runPSModel(bd,ty=experiments$TYPE[x],v=experiments$VAR[x],sc=experiments$SCALE[x],s=1056,p=i)))
  
  sfStop()
}

##########################################################################################
##################FUNCTION TO RUN THE PERTURBED/SHUFFLED CONFIG ##########################
##########################################################################################
#Function to run the CROPGRO optimiser for an specified perturbed/shuffled configuration
runPSModel <- function(bDir,ty,v,sc,s,p=NA) {
  cat("Cleaning and copying files \n")
  sp_folder <- paste(bDir,"/GJ-weather/shuf-pert/",ty,"_",v,"_",sc,sep="") #folder where S|P occur
  if (!is.na(p)) {
    if (v == "yield") {
      inpFolder <- paste(bDir,"/GJ-weather/WTH",sep="")
    } else {
      inpFolder <- paste(sp_folder,"/p-",p,"_s-",s,"/WTH",sep="")
    }
    inPSFolder <- paste(sp_folder,"/p-",p,"_s-",s,sep="")
  } else {
    if (v == "yield") {
      inpFolder <- paste(bDir,"/GJ-weather/WTH",sep="")
    } else {
      inpFolder <- paste(sp_folder,"/s-",s,"/WTH",sep="")
    }
    inPSFolder <- paste(sp_folder,"/s-",s,sep="")
  }
  if (!file.exists(paste(inPSFolder,"/proc.done",sep=""))) {
    zz <- file(paste(inPSFolder,"/proc.lock",sep=""),open="w");close(zz)
    
    #make copy of dssat here
    cat("Creating copy of DSSAT \n")
    bin_dir <- paste(bDir,"/bin",sep="")
    oCopy <- paste(bin_dir,"/dssat",sep="")
    copyNumber <- round(runif(1,0,9999),0)
    dCopy <- paste(bin_dir,"/dssat_c-",copyNumber,sep="")
    while (file.exists(dCopy)) {
      copyNumber <- round(runif(1,0,9999),0)
      dCopy <- paste(bin_dir,"/dssat_c-",copyNumber,sep="")
    }
    dir.create(dCopy)
    binList <- list.files(oCopy)
    binList <- lapply(binList,function(x,idir,odir) {k<-file.copy(paste(idir,"/",x,sep=""),paste(odir,"/",x,sep=""))},oCopy,dCopy)
    
    xDir <- dCopy #folder where CROPGRO looks for the stuff
    wthList <- list.files(xDir,pattern=".WTH")
    wthList <- lapply(wthList,function(x,idir) {k<-file.remove(paste(idir,"/",x,sep=""))},xDir)
    wthList <- list.files(inpFolder,pattern=".WTH")
    wthList <- lapply(wthList,function(x,idir,odir) {k<-file.copy(paste(idir,"/",x,sep=""),paste(odir,"/",x,sep=""))},inpFolder,xDir)
    
    #define folders for cropgro optim
    obs <- paste(inPSFolder,"/obsyield.txt",sep="")
    opt <- optSLPF(xDir,xDir,obs,slpfStep=0.05,perturbed=T) #optimise
    write.csv(opt[[1]],paste(inPSFolder,"/optimisation.csv",sep=""),quote=T,row.names=F)
    write.csv(opt[[2]],paste(inPSFolder,"/timeseries.csv",sep=""),quote=T,row.names=F)
    #control files
    file.remove(paste(inPSFolder,"/proc.lock",sep=""))
    zz <- file(paste(inPSFolder,"/proc.done",sep=""),open="w");close(zz)
    #remove dssat copy
    cat("Removing copy of DSSAT \n")
    binList <- list.files(dCopy)
    binList <- lapply(binList,function(x,idir) {k<-file.remove(paste(idir,"/",x,sep=""))},dCopy)
    setwd(oCopy); unlink(dCopy, recursive=TRUE)
    return(opt)
  }
}


########################################################################################
########## FIRST OPTIMISATION USING ORIGINAL INPUT WEATHER AND YIELD DATA
########################################################################################
#this function is specific for the lenovo configuration
firstOpt <- function() {
  pth <- "D:/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT/GJ-soil"
  xDir <- "D:/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT/GJ-exp"
  obs <- "D:/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT/GJ-yield/obsyield.txt"
  
  opt <- optSLPF(pth,xDir,obs,slpfStep=0.05,perturbed=F) #optimise
  write.csv(opt[[1]],"D:/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT/optimisation.csv",quote=T,row.names=F)
  write.csv(opt[[2]],"D:/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT/timeseries.csv",quote=T,row.names=F)
  
  tiff("D:/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT/optim-SLPF.tiff",compression='lzw',res=300,
       pointsize=8,width=1500,height=1000)
  par(mar=c(4.5,4.5,1,1),cex=0.8)
  plot(opt[[1]]$SLPF,opt[[1]]$RMSE,type="p",pch=20,xlab="Soil fertility factor (SLPF)",ylab="RMSE (kg/ha)")
  lines(opt[[1]]$SLPF,opt[[1]]$RMSE)
  grid()
  dev.off()
  
  #run best prediction
  sof <- writeSoilFile(pth,slpf='0.80') #0.8 was the best SLPF
  runCROPGRO(xDir)
  values <- accuracy(xDir,obs)[[2]]
  mn <- min(values$HWAH,values$OBYL)
  mx <- max(values$HWAH,values$OBYL)
  
  #Plot the best prediction
  tiff("D:/CIAT_work/GLAM/PNAS-paper/DSSAT-PNUT/best-pred.tiff",compression='lzw',res=300,
       pointsize=8,width=1500,height=1000)
  par(mar=c(4.5,4.5,1,1),cex=0.8)
  plot(values$YEAR,values$OBYL,type="p",pch=20,
       xlab="Year",ylab="Yield (kg/ha)",xlim=c(1966,1989),ylim=c(mn,mx))
  lines(values$YEAR,values$OBYL,col='black')
  points(values$YEAR,values$HWAH,type="p",pch=20,col='red')
  lines(values$YEAR,values$HWAH,col='red')
  grid()
  legend(1970,1800,legend=c("Observed","Modelled"),col=c("black","red"),lty=c(1,1),pch=c(20,20),cex=1.2)
  dev.off()
}

#############################################################################
##############################Optimise the SLPF##############################
#############################################################################
optSLPF <- function(sDir,expDir,obsY,slpfStep=0.05,perturbed=F) {
  #Create sequence of values
  slpfSeq <- seq(0,1,by=slpfStep); slpfSeq[1] <- 0.01
  #loop through sequence of fertility factor
  for (slpf in slpfSeq) {
    cat("\n")
    cat("Running for SLPF of",slpf,"\n")
    #Get it in the proper format
    slpfX <- paste(slpf)
    if (nchar(slpfX)!=4) {
      slpfX <- format(slpf,nsmall=2)
    }
    #Create the soil file
    cat("Creating soil file \n")
    sof <- writeSoilFile(sDir,slpf=slpfX)
    #CROPGRO run
    cat("Running crop model \n")
    if (!perturbed) {runCROPGRO(expDir)} else {runCROPGROPS(expDir)}
    #Assess prediction
    cat("Assessing prediction \n")
    accm <- accuracy(expDir,obsY)
    tims <- accm[[2]]
    tims <- cbind(SLPF=slpf,SLPFX=slpfX,tims)
    metx <- accm[[1]]
    metx <- cbind(SLPF=slpf,SLPFX=slpfX,metx)
    #Summarise output
    if (slpf==slpfSeq[1]) {
      metxRes <- metx
      timsRes <- tims
    } else {
      metxRes <- rbind(metxRes,metx)
      timsRes <- rbind(timsRes,tims)
    }
  }
  return(list(METRICS=metxRes,TIMESERIES=timsRes))
}

#############################################################################
#Read in summary and calculate performance metrics
accuracy <- function(expDir,obsYield) {
  #Check if file exists
  sFile <- paste(expDir,"/Summary.OUT",sep="")
  if (!file.exists(sFile)) {
    stop("CROPGRO Summary file does not exist")
  }
  
  if (!file.exists(obsYield)) {
    stop("Evaluation file does not exist")
  }
  
  #Reading in summary
  sData <- read.fortran(sFile,skip=4,format=c("A162","F8","A356"))
  names(sData) <- c("DUMM1","HWAH","DUMM2")
  HWAH <- sData$HWAH
  rm(sData)
  
  #Reading in obs. yield file
  yData <- read.fortran(obsYield,format=c("A12","F13"))
  names(yData) <- c("DUMM1","OBYL")
  OBYL <- yData$OBYL
  rm(yData)
  
  #complete HWAH with NA if length is not same
  if (length(OBYL) != length(HWAH)) {
    HWAH <- c(HWAH,rep(NA,times=(length(OBYL)-length(HWAH))))
  }
  
  #Calculating metrics
  rmse <- sqrt(sum((HWAH-OBYL)^2)/length(OBYL))
  corr <- cor(HWAH,OBYL)
  metx <- data.frame(RMSE=rmse,CORR=corr)
  vals <- data.frame(YEAR=1966:1989,HWAH=HWAH,OBYL=OBYL)
  return(list(METRICS=metx,VALUES=vals))
}


#############################################################################
#Run crop model from installation folder of dssat
runCROPGRO <- function(expDir) {
  #This will run CROPGRO in the specified
  setwd(expDir)
  outList <- list.files(pattern=".OUT")
  outList <- lapply(outList,function(x,idir) {k<-file.remove(paste(idir,"/",x,sep=""))},expDir)
  system("C:\\DSSAT45\\DSCSM045.EXE CRGRO045 B DSSBatch.v45",show.output.on.console=F)
}

#Run crop model if it is located in X-file folder
runCROPGROPS <- function(expDir) {
  #This will run CROPGRO in the specified
  setwd(expDir)
  outList <- list.files(pattern=".OUT")
  outList <- lapply(outList,function(x,idir) {k<-file.remove(paste(idir,"/",x,sep=""))},expDir)
  system("DSCSM045.EXE CRGRO045 B DSSBatch.v45",show.output.on.console=F)
}

#############################################################################
#Write soil file (slpf needs to be character with nchar=4)
writeSoilFile <- function(path,slpf) {
  #Validate slpf
  if (!is.character(slpf)) {
    stop("SLPF needs to be a character of length 4")
  } else if (nchar(slpf)!=4) {
    stop("SLPF needs to be a character of length 4")
  }
  
  if (as.numeric(slpf)>1 | as.numeric(slpf)<0) {
    stop("SLPF must be between 0 and 1")
  }
  
  #copy .bak into actual file
  filePathName <- paste(path,"/soil.sol",sep="")
  if (file.exists(filePathName)) {
    st <- file.remove(filePathName)
  }
  st <- file.copy(paste(path,"/soil.sol.bak",sep=""),filePathName)
  
    #write the needed stuff
  sf <- file(filePathName,"a")
  writeLines(paste("   -99  0.09   6.8  0.60  76.0  1.00  ",slpf,' IB001 IB001 IB001',sep=""),sf)
  writeLines(paste("@  SLB  SLMH  SLLL  SDUL  SSAT  SRGF  SSKS  SBDM  SLOC  SLCL  SLSI  SLCF  SLNI  SLHW  SLHB  SCEC  SADC",sep=""),sf)
  writeLines(paste("     5   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("    15   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("    28   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("    44   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("    65   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("    96   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("   122   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("   150   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("   178   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("   196   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("   200   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("   260   -99 0.350 0.450 0.480 1.000   -99  1.17  2.90   -99   -99   -99   -99   -99   -99   -99   -99 ",sep=""),sf)
  writeLines(paste("",sep=""),sf)
  close(sf)
  
  return(filePathName)
}

######## summarising functions
#function to get the summarised data and plot the results in boxplot
generalSummary <- function(bDir) {
  expList <- createExpMat(bDir)
  types <- unique(expList$TYPE)
  for (typ in types) {
    experiments <- expList[which(expList$TYPE==typ),]
    #define output names
    out_perf <- paste(bDir,"/GJ-weather/shuf-pert_results/",typ,"-performance.csv",sep="")
    out_tims <- paste(bDir,"/GJ-weather/shuf-pert_results/",typ,"-timeseries.csv",sep="")
    #if not exists open and do process
    if (!file.exists(out_tims) & !file.exists(out_perf)) {
      for (i in 1:nrow(experiments)) {
        ty <- experiments$TYPE[i]; va <- experiments$VAR[i]; sc <- experiments$SCALE[i] #get data from matrix
        cat("processing",paste(ty),"/",paste(va),"/",paste(sc),"\n")
        sp_folder <- paste(bDir,"/GJ-weather/shuf-pert/",ty,"_",va,"_",sc,sep="")
        performance <- read.csv(paste(sp_folder,"/performance.csv",sep=""))
        timeseries <- read.csv(paste(sp_folder,"/timeseries.csv",sep=""))
        if (i==1) {
          perf <- performance
          tims <- timeseries
        } else {
          perf <- rbind(perf,performance)
          tims <- rbind(tims,timeseries)
        }
      }
      write.csv(perf,out_perf,quote=F,row.names=F)
      write.csv(tims,out_tims,quote=F,row.names=F)
    }
  }
}


####################################################################################
####################################################################################
#function to summarise experiments
summariseExperiments <- function(bDir) {
  experiments <- createExpMat(bDir) #change when perturbed runs are ready
  for (i in 1:nrow(experiments)) {
    ty <- experiments$TYPE[i]; va <- experiments$VAR[i]; sc <- experiments$SCALE[i] #get data from matrix
    cat("\n")
    cat("processing",paste(ty),"/",paste(va),"/",paste(sc),"\n")
    #list folders and loop to get what we need
    sp_folder <- paste(bDir,"/GJ-weather/shuf-pert/",ty,"_",va,"_",sc,sep="")
    if (!file.exists(paste(sp_folder,"/timeseries.csv",sep=""))) {
      f_list <- list.files(sp_folder); f_list <- f_list[grep("s-",f_list)]
      
      #verify whether preliminary files exist
      nfil <- length(f_list)/1000
      pfc <- 1
      for (pf in 1:nfil) {
        per_file <- paste(sp_folder,"/performance_",pf,".csv",sep="")
        tse_file <- paste(sp_folder,"/timeseries_",pf,".csv",sep="")
        
        if (file.exists(per_file) & file.exists(tse_file)) {
          cat("Block",pf,"was already analysed, skipping files \n")
          to_skip <- ((pf-1)*1000+1):((pf-1)*1000+1000)
          if (pfc==1) {
            cum_skipped <- to_skip
          } else {
            cum_skipped <- c(cum_skipped,to_skip)
          }
          pfc <- pfc+1
        }
      }
      
      #reducing f_list
      if (pfc>1) {
        f_list_red <- f_list[-cum_skipped]
      } else {
        f_list_red <- f_list
      }
      
      fcount <- 1
      scount <- pfc
      for (f_name in f_list_red) {
        cat("reading in experiment",f_name,"\n")
        PSDataFolder <- paste(sp_folder,"/",f_name,sep="") #data folder
        opt <- read.csv(paste(PSDataFolder,"/optimisation.csv",sep="")) #load optimisation curve
        tse <- read.csv(paste(PSDataFolder,"/timeseries.csv",sep="")) #load time series
        best_slpf <- opt$SLPF[which(opt$RMSE == min(opt$RMSE,na.rm=T))] #get best slpf
        if (length(best_slpf)>1) { #get highest best slpf in the case there is more than 1
          best_slpf <- max(best_slpf)
        }
        #get metrics for best slpf
        best_rmse <- opt$RMSE[which(opt$SLPF==best_slpf)]
        best_corr <- opt$CORR[which(opt$SLPF==best_slpf)]
        best_tser <- tse[which(tse$SLPF==best_slpf),]
        if (ty == "s") { #get experimental details
          p <- NA
          s <- as.numeric(gsub("s-","",f_name))
        } else {
          p <- as.numeric(gsub("p-","",strsplit(f_name,"_")[[1]][1]))
          s <- as.numeric(gsub("s-","",strsplit(f_name,"_")[[1]][2]))
        }
        #get the performance row
        per_row <- data.frame(TYPE=ty,VAR=va,SCALE=sc,P=p,SEED=s,SLPF=best_slpf,RMSE=best_rmse,CORR=best_corr)
        #get the best time series
        best_tse <- data.frame(TYPE=ty,VAR=va,SCALE=sc,P=p,SEED=s,SLPF=best_slpf,
                               YEAR=best_tser$YEAR,HWAH=best_tser$HWAH,OBYL=best_tser$OBYL)
        if (fcount==1) { #summarise
          performance <- per_row
          timeseries <- best_tse
        } else {
          performance <- rbind(performance,per_row)
          timeseries <- rbind(timeseries,best_tse)
        }
        
        #restart counter and write preliminary file to avoid heavy matrices, these will
        #be merged at the end
        if (fcount==1000) {
          write.csv(performance,paste(sp_folder,"/performance_",scount,".csv",sep=""),row.names=F,quote=F)
          write.csv(timeseries,paste(sp_folder,"/timeseries_",scount,".csv",sep=""),row.names=F,quote=F)
          scount <- scount+1
          fcount <- 1
          rm(performance); rm(timeseries); g=gc(); rm(g)
        } else {
          fcount <- fcount+1
        }
      }
      
      if (nfil>1) {
        cat("Concatenating ")
        for (sc in 1:nfil) {
          per_pre <- read.csv(paste(sp_folder,"/performance_",sc,".csv",sep=""))
          tim_pre <- read.csv(paste(sp_folder,"/timeseries_",sc,".csv",sep=""))
          if (sc==1) {
            performance <- per_pre
            timeseries <- tim_pre
          } else {
            performance <- rbind(performance,per_pre)
            timeseries <- rbind(timeseries,tim_pre)
          }
        }
      }
      write.csv(performance,paste(sp_folder,"/performance.csv",sep=""),row.names=F,quote=F)
      write.csv(timeseries,paste(sp_folder,"/timeseries.csv",sep=""),row.names=F,quote=F)
      
      rm(performance);rm(timeseries);g=gc();rm(g)
    }
  }
}
