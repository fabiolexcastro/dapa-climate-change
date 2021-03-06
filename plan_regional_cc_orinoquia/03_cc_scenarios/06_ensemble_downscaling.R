source("ensemble_downscaling.R")
baseDir="//dapadfs/workspace_cluster_6/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/01-datos_clima/downscaling_GCM"
rcp='rcp85'
oDir="//dapadfs/workspace_cluster_6/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/01-datos_clima/ensemble_GCM/14_gcm"
otp<- GCMEnsembleDown(baseDir, rcp, oDir)

#####################################################################
# Description: This function is to calculate an ensemble of downscaling
#####################################################################
GCMEnsembleDown <- function(baseDir="//dapadfs/workspace_cluster_6/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/01-datos_clima/downscaling_GCM", rcp='rcp26', oDir="//dapadfs/workspace_cluster_6/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/01-datos_clima/ensemble_GCM") {
  
  require(raster)
  require(ncdf)
  
  # rcpList <- c("rcp26", "rcp45", "rcp85")
  
  # List of variables and months
  varList <- c("prec", "tmax", "tmin", "tmean")
  mthList <- c(1:12)
  
  # for (rcp in rcpList){
  
  if (!file.exists(paste(oDir, "/", rcp, sep=""))) {dir.create(paste(oDir, "/", rcp, sep=""), recursive=T)}
  
  # gcmList <- list.dirs(paste(baseDir, "/_", rcp, sep=""), recursive = FALSE, full.names = TRUE)
  gcmList <- c("bcc_csm1_1", "ncar_ccsm4", "csiro_mk3_6_0", "gfdl_cm3", "giss_e2_h", "giss_e2_r", "mohc_hadgem2_es", "ipsl_cm5a_lr", "ipsl_cm5a_mr", "miroc_miroc5", "miroc_esm", "miroc_esm_chem", "mri_cgcm3", "ncc_noresm1_m")
  
  cat("Ensemble over: ", rcp)

  for (var in varList){
    
    for (mth in mthList){
      
      setwd(paste(baseDir, "/", rcp, sep=""))
      gcmStack <- stack(lapply(paste0(gcmList, "/", var, "_", mth, ".nc"),FUN=raster))
      
      gcmMean <- mean(gcmStack)
      fun <- function(x) { sd(x) }
      gcmStd <- calc(gcmStack, fun)

      if (var != "prec"){
        gcmMean <- trunc(gcmMean * 10)
        gcmStd <- trunc(gcmStd * 10)
      } else {
        gcmMean <- trunc(gcmMean)
        gcmStd <- trunc(gcmStd)
      }
      
      gcmMean <- writeRaster(gcmMean, paste(oDir, "/", rcp, "/", var, "_", mth, ".asc", sep=""), overwrite=FALSE)
      gcmStd <- writeRaster(gcmStd, paste(oDir, "/", rcp, "/", var, "_", mth, "_sd.asc", sep=""), overwrite=FALSE)
      
    }
  }
  
  cat(" .. done!/n")
          
  # }
}  
