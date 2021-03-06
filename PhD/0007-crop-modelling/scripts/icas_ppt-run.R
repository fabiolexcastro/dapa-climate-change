#Julian Ramirez-Villegas
#University of Leeds / CCAFS / CIAT
#October 2012

### script to make some nice charts for 15th Oct ICAS presentation
### some of these functions are to be re-used for further PhD reporting
stop("STop!!!")
library(raster)
library(maptools); data(wrld_simpl)

#local dirs
src.dir <- "D:/_tools/dapa-climate-change/trunk/PhD/0007-crop-modelling/scripts"
bDir <- "W:/eejarv/PhD-work/crop-modelling/GLAM"
cmip5_dir <- "V:/eejarv/CMIP5"

#sourcing scripts
source(paste(src.dir,"/icas_ppt-functions.R",sep=""))

#name of crop and other details
cropName <- "gnut"
selection <- "v6"

#other directories
cropDir <- paste(bDir,"/model-runs/",toupper(cropName),sep="")
out_dir <- paste(bDir,"/climate-change",sep="")
histDir <- paste(cmip5_dir,"/baseline",sep="")
rcpDir <- paste(cmip5_dir,"/rcp45",sep="")

#load gridcell details
cells <- read.csv(paste(cropDir,"/inputs/calib-cells-selection-",selection,".csv",sep=""))

#output directory
out_dir <- "Z:/PhD-work/icas_talk_2012"


##################################################################
##################################################################
#PART 1: model calibration maps and scattergrams

#for experiment 33 make 
   #maps of ccoef, rmse, ypred/yobs, sdpred/sdobs
   #scattergrams of sdobs vs sdpred
expID <- 33
expDir <- paste(cropDir,"/calib/exp-",expID,"_outputs",sep="")

#load model performance data
mod_res <- read.csv(paste(expDir,"/general/calib_all_cells.csv",sep=""))

#load raster data
ccoef <- raster(paste(expDir,"/general/calib_results_spat/ccoef.asc",sep=""))
rmse <- raster(paste(expDir,"/general/calib_results_spat/rmse.asc",sep=""))
ypred <- raster(paste(expDir,"/general/calib_results_spat/y_pred.asc",sep=""))
yobs <- raster(paste(expDir,"/general/calib_results_spat/y_obs.asc",sep=""))
sdpred <- raster(paste(expDir,"/general/calib_results_spat/ysd_pred.asc",sep=""))
sdobs <- raster(paste(expDir,"/general/calib_results_spat/ysd_obs.asc",sep=""))
yp_yo <- ypred/yobs
sdp_sdo <- sdpred/sdobs

#number of breaks
nbrks <- 20

#mean yield
cols <- c(colorRampPalette(c("green","yellow","orange","red"))(nbrks))
brks <- seq(min(yobs[],ypred[],na.rm=T),max(yobs[],ypred[],na.rm=T),length.out=nbrks)
tName <- paste(out_dir,"/exp-",expID,"_y_obs.tif",sep="")
make_spplot(prs=yobs,pcols=cols,pbrks=brks,ht=1000,tiffName=tName)
tName <- paste(out_dir,"/exp-",expID,"_y_pred.tif",sep="")
make_spplot(prs=ypred,pcols=cols,pbrks=brks,ht=1000,tiffName=tName)

#sd yield
brks <- seq(min(sdobs[],sdpred[],na.rm=T),max(sdobs[],sdpred[],na.rm=T),length.out=nbrks)
tName <- paste(out_dir,"/exp-",expID,"_ysd_obs.tif",sep="")
make_spplot(prs=sdobs,pcols=cols,pbrks=brks,ht=1000,tiffName=tName)
tName <- paste(out_dir,"/exp-",expID,"_ysd_pred.tif",sep="")
make_spplot(prs=sdpred,pcols=cols,pbrks=brks,ht=1000,tiffName=tName)

#mean yield ratios, yp_yo
brks <- seq(0,max(yp_yo[],na.rm=T),length.out=12)
cols <- c(colorRampPalette(c("dark green","green","yellow","orange","red"))(12))
tName <- paste(out_dir,"/exp-",expID,"_yp_by_yo.tif",sep="")
make_spplot(prs=yp_yo,pcols=cols,pbrks=brks,ht=1000,tiffName=tName)

#sd yield ratios, yp_yo
brks <- seq(0,max(sdp_sdo[],na.rm=T),length.out=12)
tName <- paste(out_dir,"/exp-",expID,"_sdp_by_sdo.tif",sep="")
make_spplot(prs=sdp_sdo,pcols=cols,pbrks=brks,ht=1000,tiffName=tName)

#rmse
brks <- seq(min(rmse[],na.rm=T),max(rmse[],na.rm=T),length.out=nbrks)
cols <- rev(c(colorRampPalette(c("red","orange","yellow","green","dark green"))(nbrks)))
tName <- paste(out_dir,"/exp-",expID,"_rmse.tif",sep="")
make_spplot(prs=rmse,pcols=cols,pbrks=brks,ht=1000,tiffName=tName)

#ccoef
xysig <- cbind(x=mod_res$X[which(mod_res$CCOEF > 0 & mod_res$PVAL <= 0.05 & cells$AHRATIO >= 0.2)],
               y=mod_res$Y[which(mod_res$CCOEF > 0 & mod_res$PVAL <= 0.05 & cells$AHRATIO >= 0.2)])
xysig <- SpatialPoints(xysig)
pts2 <- list("sp.points", xysig, pch = 20, col = "black", cex=0.75, lwd=0.6,first=F)
brks <- seq(-1,1,length.out=21)
cols <- c(colorRampPalette(c("red","orange","yellow","green","dark green"))(nbrks))
tName <- paste(out_dir,"/exp-",expID,"_ccoef.tif",sep="")
make_spplot(prs=ccoef,pcols=cols,pbrks=brks,ht=1000,tiffName=tName,add_items=c(pts2))

#xyplot for mean yield
rval <- cor.test(mod_res$Y_PRED,mod_res$Y_OBS)$estimate
pval <- cor.test(mod_res$Y_PRED,mod_res$Y_OBS)$p.value
lims <- c(0,max(mod_res$Y_PRED,mod_res$Y_OBS))
tiffName <- paste(out_dir,"/exp-",expID,"_yobs_ypred_xy.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=8)
par(mar=c(5,5,2,1))
plot(mod_res$Y_PRED,mod_res$Y_OBS,pch=20,cex=0.75,xlim=lims,ylim=lims,
     xlab="Predicted yield (kg/ha)",
     ylab="Observed yield (kg/ha)",
     main=paste("CCOEF=",round(rval,3)," / (p=",round(pval,6),")",sep=""))
abline(0,1)
grid()
dev.off()

#xyplot for sd yield
lims <- c(0,max(mod_res$YSD_PRED,mod_res$YSD_OBS))
rval <- cor.test(mod_res$YSD_PRED,mod_res$YSD_OBS)$estimate
pval <- cor.test(mod_res$YSD_PRED,mod_res$YSD_OBS)$p.value
tiffName <- paste(out_dir,"/exp-",expID,"_sdobs_sdpred_xy.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=8)
par(mar=c(5,5,2,1))
plot(mod_res$YSD_PRED,mod_res$YSD_OBS,pch=20,cex=0.75,xlim=lims,ylim=lims,
     xlab="Predicted yield s.d. (kg/ha)",
     ylab="Observed yield s.d. (kg/ha)",
     main=paste("CCOEF=",round(rval,3)," / (p=",round(pval,6),")",sep=""))
abline(0,1)
grid()
dev.off()


##################################################################
##################################################################
#PART 2: GLAM ensemble

### take a gridcell in Gujarat with high ccoef and show the ensemble runs
loc <- 635

#years to analyse
yi <- 1966
yf <- 1993

####load list of experiments that were selected
parset_list <- read.csv(paste(cropDir,"/calib/results_exp/summary_exp_33-82/runs_discard.csv",sep=""))
runs_ref <- parset_list[which(parset_list$ISSEL==1),]
row.names(runs_ref) <- 1:nrow(runs_ref)

#load observed yield
yo_data <- read.fortran(file=paste(cropDir,"/inputs/ascii/obs/yield_",loc,"_lin.txt",sep=""),
                        format=c("3I4","F8"))
names(yo_data) <- c("YEAR","ILAT","ILON","YIELD")
yo_data <- yo_data[which(yo_data$YEAR >= yi & yo_data$YEAR <= yf),]

#load irrigation rates
irDir <- paste(cropDir,"/irrigated_ratio",sep="")
ir_stk <- stack(paste(irDir,"/raw-",yi:yf,".asc",sep=""))
ir_vls <- extract(ir_stk,cbind(X=cells$X[which(cells$CELL==loc)],Y=cells$Y[which(cells$CELL==loc)]))
ir_vls <- as.numeric(ir_vls)
ir_vls <- data.frame(YEAR=yi:yf,IRATIO=ir_vls)
ir_vls$IRATIO[which(ir_vls$IRATIO > 1)] <- 1

all_runs <- data.frame(YEAR=yi:yf,OBS=yo_data$YIELD)

#load irrigated and rainfed run data for all experiments
for (expID in runs_ref$EXPID) {
  expDir <- paste(cropDir,"/calib/exp-",expID,"_outputs",sep="")
  locDir <- paste(expDir,"/gridcells/fcal_",loc,sep="")
  
  #load data
  rfd_fil <- paste(locDir,"/groundnut_RFD.out",sep="")
  rfd_dat <- read.table(rfd_fil,sep="\t")
  names(rfd_dat) <- c("YEAR","LAT","LON","PLANTING_DATE","STG","RLV_M","LAI","YIELD","BMASS","SLA",
                      "HI","T_RAIN","SRAD_END","PESW","TRANS","ET","P_TRANS+P_EVAP","SWFAC","EVAP+TRANS",
                      "RUNOFF","T_RUNOFF","DTPUPTK","TP_UP","DRAIN","T_DRAIN","P_TRANS","TP_TRANS",
                      "T_EVAP","TP_EVAP","T_TRANS","RLA","RLA_NORM","RAIN_END","DSW","TRADABS",
                      "DUR","VPDTOT","TRADNET","TOTPP","TOTPP_HIT","TOTPP_WAT","TBARTOT")
  run_data <- data.frame(YEAR=rfd_dat$YEAR,RFD=rfd_dat$YIELD)
  
  irr_fil <- paste(locDir,"/groundnut_IRR.out",sep="")
  irr_dat <- read.table(irr_fil,sep="\t")
  names(irr_dat) <- c("YEAR","LAT","LON","PLANTING_DATE","STG","RLV_M","LAI","YIELD","BMASS","SLA",
                      "HI","T_RAIN","SRAD_END","PESW","TRANS","ET","P_TRANS+P_EVAP","SWFAC","EVAP+TRANS",
                      "RUNOFF","T_RUNOFF","DTPUPTK","TP_UP","DRAIN","T_DRAIN","P_TRANS","TP_TRANS",
                      "T_EVAP","TP_EVAP","T_TRANS","RLA","RLA_NORM","RAIN_END","DSW","TRADABS",
                      "DUR","VPDTOT","TRADNET","TOTPP","TOTPP_HIT","TOTPP_WAT","TBARTOT")
  run_data$IRR <- irr_dat$YIELD
  run_data$IRATIO <- ir_vls$IRATIO
  
  run_data$YIELD <- run_data$IRR*run_data$IRATIO + run_data$RFD*(1-run_data$IRATIO)
  all_runs$VALUE <- run_data$YIELD
  names(all_runs)[ncol(all_runs)] <- paste("EXP.",expID,sep="")
}

#calculate ensemble mean
all_runs$ENS.MEAN <- rowMeans(all_runs[,3:21],na.rm=T)
all_runs$ENS.SD <- apply(all_runs[,3:21],1,FUN=function(x) {sd(x,na.rm=T)})
all_runs$ENS.MIN <- apply(all_runs[,3:21],1,FUN=function(x) {min(x,na.rm=T)})
all_runs$ENS.MAX <- apply(all_runs[,3:21],1,FUN=function(x) {max(x,na.rm=T)})

#plot all things
tiffName <- paste(out_dir,"/loc-",loc,"_hist_run.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(mar=c(5,5,1,1))
plot(all_runs$YEAR,all_runs$OBS,ty="l",xlab=NA,ylab="Yield (kg/ha)",
     ylim=c(min(all_runs$ENS.MIN),max(all_runs$ENS.MAX)),lwd=1.2)

#loop the single members
for (expID in runs_ref$EXPID) {
  lines(all_runs$YEAR,all_runs[,paste("EXP.",expID,sep="")],col="pink",lwd=0.75)
}
lines(all_runs$YEAR,all_runs$OBS,col="black",lwd=1.2)
lines(all_runs$YEAR,all_runs$ENS.MEAN,col="red",lwd=1.2)
grid()
dev.off()

cor_all <- apply(all_runs[,3:21],2,FUN=function(x,y) {cor(x,y)}, all_runs$OBS)


##################################################################
##################################################################
#PART 3: compare crop and climate uncertainties

#part 3a
#get all climate runs for an experiment (exp-36)
loc <- 635
best_exp <- names(which(cor_all==max(cor_all)))
best_exp <- gsub("EXP.","",best_exp)

#initial data loading
#load observed yield
yo_data <- read.fortran(file=paste(cropDir,"/inputs/ascii/obs/yield_",loc,"_lin.txt",sep=""),
                        format=c("3I4","F8"))
names(yo_data) <- c("YEAR","ILAT","ILON","YIELD")
yo_data <- yo_data[which(yo_data$YEAR >= yi & yo_data$YEAR <= yf),]

#load irrigation rates
irDir <- paste(cropDir,"/irrigated_ratio",sep="")
ir_stk <- stack(paste(irDir,"/raw-",yi:yf,".asc",sep=""))
ir_vls <- extract(ir_stk,cbind(X=cells$X[which(cells$CELL==loc)],Y=cells$Y[which(cells$CELL==loc)]))
ir_vls <- as.numeric(ir_vls)
ir_vls <- data.frame(YEAR=yi:yf,IRATIO=ir_vls)
ir_vls$IRATIO[which(ir_vls$IRATIO > 1)] <- 1

#directories
cmip5_hist <- paste(cropDir,"/runs/cmip5_hist",sep="")
expDir_hist <- paste(cmip5_hist,"/exp-",best_exp,"_outputs",sep="")

#list of gcms
gcmList <- list.files(expDir_hist)
out_all <- data.frame()
for (gcm in gcmList) {
  for (runtype in c("allin","norain","nosrad","notemp")) {
    locDir <- paste(expDir_hist,"/",gcm,"/",runtype,"_",loc,sep="")
    
    #load output.RData
    load(file=paste(locDir,"/iter-ygp/output.RData",sep=""))
    
    #find which calib run has the optimal ygp, and grab its rmse
    best_run <- which(optimised$YGP$VALUE == optimal$YGP)
    
    #directories and files
    rf_dir <- paste(locDir,"/iter-ygp/ygp/RFD_run-",best_run,"_",optimal$YGP,sep="")
    rfd_dat <- paste(rf_dir,"/output/groundnut.out",sep="")
    ir_dir <- paste(locDir,"/iter-ygp/ygp/IRR_run-",best_run,"_",optimal$YGP,sep="")
    irr_dat <- paste(ir_dir,"/output/groundnut.out",sep="")
    
    if (file.exists(rfd_dat) & file.exists(irr_dat)) {
      #get rmse
      rmse_gcm <- optimised$YGP$RMSE[best_run]
      
      #load rainfed run data
      rfd_dat <- read.table(rfd_dat,sep="\t")
      names(rfd_dat) <- c("YEAR","LAT","LON","PLANTING_DATE","STG","RLV_M","LAI","YIELD","BMASS","SLA",
                          "HI","T_RAIN","SRAD_END","PESW","TRANS","ET","P_TRANS+P_EVAP","SWFAC","EVAP+TRANS",
                          "RUNOFF","T_RUNOFF","DTPUPTK","TP_UP","DRAIN","T_DRAIN","P_TRANS","TP_TRANS",
                          "T_EVAP","TP_EVAP","T_TRANS","RLA","RLA_NORM","RAIN_END","DSW","TRADABS",
                          "DUR","VPDTOT","TRADNET","TOTPP","TOTPP_HIT","TOTPP_WAT","TBARTOT")
      run_data <- data.frame(YEAR=rfd_dat$YEAR,RFD=rfd_dat$YIELD)
      
      #load irrigated run data
      irr_dat <- read.table(irr_dat,sep="\t")
      names(irr_dat) <- c("YEAR","LAT","LON","PLANTING_DATE","STG","RLV_M","LAI","YIELD","BMASS","SLA",
                          "HI","T_RAIN","SRAD_END","PESW","TRANS","ET","P_TRANS+P_EVAP","SWFAC","EVAP+TRANS",
                          "RUNOFF","T_RUNOFF","DTPUPTK","TP_UP","DRAIN","T_DRAIN","P_TRANS","TP_TRANS",
                          "T_EVAP","TP_EVAP","T_TRANS","RLA","RLA_NORM","RAIN_END","DSW","TRADABS",
                          "DUR","VPDTOT","TRADNET","TOTPP","TOTPP_HIT","TOTPP_WAT","TBARTOT")
      run_data$IRR <- irr_dat$YIELD
      run_data$IRATIO <- ir_vls$IRATIO
      run_data$YIELD <- run_data$IRR*run_data$IRATIO + run_data$RFD*(1-run_data$IRATIO)
    }
      
    #calculate mean yield
    ybar <- mean(run_data$YIELD,na.rm=T)
    
    #calculate sigma yield
    ysig <- sd(run_data$YIELD,na.rm=T)
    
    #output data.frame
    out_df <- data.frame(GCM=gcm,RUN_TYPE=runtype,MEAN=ybar,SD=ysig,RMSE=rmse_gcm)
    out_all <- rbind(out_all,out_df)
  }
}

ybar_obs <- mean(yo_data$YIELD,na.rm=T)
ysig_obs <- sd(yo_data$YIELD,na.rm=T)
rmse_all <- apply(all_runs[,3:21],2,FUN=function(x,y) {rmse(x,y)}, all_runs$OBS)
ybar_all <- apply(all_runs[,3:21],2,FUN=function(x) {mean(x,na.rm=T)})
ysig_all <- apply(all_runs[,3:21],2,FUN=function(x) {sd(x,na.rm=T)})

ctr_df <- data.frame(GCM="control",RUN_TYPE="control",MEAN=as.numeric(ybar_all),
                     SD=as.numeric(ysig_all),RMSE=as.numeric(rmse_all))
out_all <- rbind(out_all,ctr_df)
out_all$MEAN_NORM <- out_all$MEAN/ybar_obs
out_all$SD_NORM <- out_all$SD/ysig_obs

gcm_tab <- paste(out_all$GCM)
gcm_tab <- lapply(gcm_tab,FUN=function(x) {strsplit(x,"_ENS_",fixed=T)[[1]][1]})
gcm_tab <- unlist(gcm_tab)
out_all <- cbind(GCM_NAME=gcm_tab,out_all)

texp_ybar <- ybar_all[which(names(ybar_all) == paste("EXP.",best_exp,sep=""))] / ybar_obs
texp_ysig <- ysig_all[which(names(ysig_all) == paste("EXP.",best_exp,sep=""))] / ysig_obs
texp_rmse <- rmse_all[which(names(rmse_all) == paste("EXP.",best_exp,sep=""))]

#a boxplot that shows the variation of all run_types each gcm
tiffName <- paste(out_dir,"/loc-",loc,"_gcm_biases_mean.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(10,5,1,1),lwd=0.75)
boxplot(out_all$MEAN_NORM~out_all$GCM_NAME,pch=20,col="grey",
        ylab="Mean yield (normalised by observed)")
abline(h=texp_ybar,col="red")
grid()
dev.off()

tiffName <- paste(out_dir,"/loc-",loc,"_gcm_biases_sd.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(10,5,1,1),lwd=0.75)
boxplot(out_all$SD_NORM~out_all$GCM_NAME,pch=20,col="grey",
        ylab="S.d. yield (normalised by observed)")
abline(h=texp_ysig,col="red")
grid()
dev.off()

tiffName <- paste(out_dir,"/loc-",loc,"_gcm_biases_rmse.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(10,5,1,1),lwd=0.75)
boxplot(out_all$RMSE~out_all$GCM_NAME,pch=20,col="grey",
        ylab="RMSE (kg/ha)")
abline(h=texp_rmse,col="red")
grid()
dev.off()


#a boxplot that shows the variation of all GCMs for each run_type
tiffName <- paste(out_dir,"/loc-",loc,"_gcm_runtype_biases_mean.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(5,5,1,1),lwd=0.75)
boxplot(out_all$MEAN_NORM~out_all$RUN_TYPE,pch=20,col="grey",
        ylab="Mean yield (normalised by observed)")
abline(h=texp_ybar,col="red")
grid()
dev.off()

tiffName <- paste(out_dir,"/loc-",loc,"_gcm_runtype_biases_sd.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(5,5,1,1),lwd=0.75)
boxplot(out_all$SD_NORM~out_all$RUN_TYPE,pch=20,col="grey",
        ylab="S.d. yield (normalised by observed)")
abline(h=texp_ysig,col="red")
grid()
dev.off()

tiffName <- paste(out_dir,"/loc-",loc,"_gcm_runtype_biases_rmse.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(5,5,1,1),lwd=0.75)
boxplot(out_all$RMSE~out_all$RUN_TYPE,pch=20,col="grey",
        ylab="RMSE (kg/ha)")
abline(h=texp_rmse,col="red")
grid()
dev.off()


#take one of the best models and show the rmse as a barplot compared with control simulation
#(hadgem2_cc)
this_gcm <- "mohc_hadgem2_cc"
gcm_data <- out_all[which(out_all$GCM_NAME == this_gcm),]

ctr_ybar <- mean(out_all$MEAN_NORM[which(out_all$GCM_NAME == "control")],na.rm=T)
ctr_ybar_sd <- sd(out_all$MEAN_NORM[which(out_all$GCM_NAME == "control")],na.rm=T)
ctr_ysig <- mean(out_all$SD_NORM[which(out_all$GCM_NAME == "control")],na.rm=T)
ctr_ysig_sd <- sd(out_all$SD_NORM[which(out_all$GCM_NAME == "control")],na.rm=T)
ctr_rmse <- mean(out_all$RMSE[which(out_all$GCM_NAME == "control")],na.rm=T)
ctr_rmse_sd <- sd(out_all$RMSE[which(out_all$GCM_NAME == "control")],na.rm=T)

gcm_data <- rbind(gcm_data,data.frame(GCM_NAME="control",GCM="control",RUN_TYPE="control",
                                      MEAN=ctr_ybar,SD=ctr_ysig,RMSE=ctr_rmse,
                                      MEAN_NORM=ctr_ybar,SD_NORM=ctr_ysig))

tiffName <- paste(out_dir,"/loc-",loc,"_",this_gcm,"_runtype_biases_mean.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(5,5,1,1),lwd=0.75)
barplot(gcm_data$MEAN_NORM,col="grey",ylab="Mean yield (normalised by observed)",
        names.arg=paste(gcm_data$RUN_TYPE),ylim=c(0,1))
lines(c(5.5,5.5),c((ctr_ybar-ctr_ybar_sd*1.5),(ctr_ybar+ctr_ybar_sd*1.5)))
points(5.5,texp_ybar,pch=20,col="red")
grid()
dev.off()

tiffName <- paste(out_dir,"/loc-",loc,"_",this_gcm,"_runtype_biases_sd.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(5,5,1,1),lwd=0.75)
barplot(gcm_data$SD_NORM,col="grey",ylab="S.d. yield (normalised by observed)",
        names.arg=paste(gcm_data$RUN_TYPE),ylim=c(0,1.5))
lines(c(5.5,5.5),c((ctr_ysig-ctr_ysig_sd*1.5),(ctr_ysig+ctr_ysig_sd*1.5)))
points(5.5,texp_ysig,pch=20,col="red")
grid()
dev.off()

tiffName <- paste(out_dir,"/loc-",loc,"_",this_gcm,"_runtype_biases_rmse.tif",sep="")
tiff(tiffName,res=300,compression="lzw",height=1000,width=1000,pointsize=6.5)
par(las=2,mar=c(5,5,1,1),lwd=0.75)
barplot(gcm_data$RMSE,col="grey",ylab="RMSE (kg/ha)",
        names.arg=paste(gcm_data$RUN_TYPE))
lines(c(5.5,5.5),c((ctr_rmse-ctr_rmse_sd*1.5),(ctr_rmse+ctr_rmse_sd*1.5)))
points(5.5,texp_rmse,pch=20,col="red")
grid()
dev.off()


###################################################
## part b: get all GLAM runs for a gcm
#get all GLAM runs for hadgem2_cc


#plot that shows variation in all simulations (inputs removed)










