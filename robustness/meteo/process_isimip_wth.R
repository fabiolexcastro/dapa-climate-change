#Julian Ramirez-Villegas
#UoL / CCAFS
#Jan 2014

stop("!")
#process ISIMIP meteorology:
#1. resample yield data resolution (using 2nd order conservative remapping)
#2. cut to african domain

#load libraries
library(sp); library(raster); library(rgdal); library(maptools)

#input directories
#wd <- "~/Leeds-work/quest-for-robustness"
wd <- "/nfs/a101/eejarv/quest-for-robustness"
srcDir <- paste(wd,"/scripts",sep="")
#metDir <- paste(wd,"/data/meteorology/ISIMIP_wth",sep="")
metDir <- "/nfs/a101/earak/data/ISIMIP_wth"
yiDir <- paste(wd,"/data/yield_data_maize",sep="")
sowDir <- paste(wd,"/data/crop_calendar_sacks",sep="")

#output directory
ometDir <- paste(wd,"/data/meteorology/future_climate",sep="")
if (!file.exists(ometDir)) {dir.create(ometDir)}

#list of GCMs, emission scenarios, periods and variables
gcm_list <- c("gfdl-esm2m","hadgem2-es","ipsl-cm5a-lr","miroc-esm-chem","noresm1-m")
sce_list <- c("hist","rcp26","rcp45","rcp60","rcp85")
hisp_list <- c("1950","1951-1960","1961-1970","1971-1980","1981-1990","1991-2000","2001-2005")
hisp_list2 <- c("1950","1951-1960","1961-1970","1971-1980","1981-1990","1991-2000","2001-2004")

futp_list <- c("2006-2010","2011-2020","2021-2030","2031-2040","2041-2050","2051-2060",
               "2061-2070","2071-2080","2081-2090","2091-2099")
futp_list2 <- c("2005-2010","2011-2020","2021-2030","2031-2040","2041-2050","2051-2060",
               "2061-2070","2071-2080","2081-2090","2091-2099")
var_list <- c("pr","rsds","tasmax","tasmin")

#read in yield data for getting mask
yrs <- raster(paste(yiDir,"/descriptive_stats/mean_ModelYld500.tif",sep=""))

#determine extent to cut the resampled netcdf
bbox <- extent(yrs)
if (bbox@xmin < 0)  bbox@xmin <- bbox@xmin+360
if (bbox@xmax < 0)  bbox@xmax <- bbox@xmax+360

#function to process isimip weather data
process_isimip_wth <- function(gcm, sce) {
  #i/o folder of gcm and scenario
  igcmDir <- paste(metDir,"/",gcm,"/",sce,sep="")
  ogcmDir <- paste(ometDir,"/",gcm,"/",sce,sep="")
  if (!file.exists(ogcmDir)) {dir.create(ogcmDir,recursive=T)}
  
  #defining list of years and aspects of file names
  if (sce == "hist") {
    scename <- "hist"; year_list <- hisp_list
    if (gcm == "hadgem2-es") {year_list <- hisp_list2}
  } else if (sce == "rcp26") {
    scename <- "rcp2p6"; year_list <- futp_list
    if (gcm == "hadgem2-es") {year_list <- futp_list2}
  } else if (sce == "rcp45") {
    scename <- "rcp4p5"; year_list <- futp_list
    if (gcm == "hadgem2-es") {year_list <- futp_list2}
  } else if (sce == "rcp60") {
    scename <- "rcp6p0"; year_list <- futp_list
    if (gcm == "hadgem2-es") {year_list <- futp_list2}
  } else {
    scename <- "rcp8p5"; year_list <- futp_list
    if (gcm == "hadgem2-es") {year_list <- futp_list2}
  }
  
  #loop variable names and periods
  for (vname in var_list) {
    #vname <- "pr"
    cat("...processing variable",vname,"\n")
    for (years in year_list) {
      #years <- year_list[1]
      cat("...processing period",years,"\n")
      
      #name of file
      fname <- paste(vname,"_bced_1960_1999_",gcm,"_",scename,"_",years,".nc",sep="")
      fnameout <- paste("afr_",vname,"_bced_1960_1999_",gcm,"_",scename,"_",years,".nc",sep="")
      
      if (!file.exists(paste(ogcmDir,"/",fnameout,sep=""))) {
        #cdo for remapping onto a different grid
        setwd(igcmDir)
        system(paste("cdo remapcon2,r320x160 ",fname," ",ogcmDir,"/",vname,"_remapped.nc",sep=""))
        setwd(ogcmDir)
        
        #cut to Africa
        system(paste("cdo sellonlatbox,",bbox@xmin,",",bbox@xmax,",",bbox@ymin,",",bbox@ymax," ",vname,"_remapped.nc ",fnameout,sep=""))
        
        #note: for some reason the below was required for the following file:
        #/nfs/a101/eejarv/quest-for-robustness/data/meteorology/future_climate/gfdl-esm2m/rcp26/afr_pr_bced_1960_1999_gfdl-esm2m_rcp2p6_2011-2020.nc
        #uncomment the below and comment out the above cut to Africa
        #system(paste("cdo sellonlatbox,",bbox@xmin-0.5625,",",bbox@xmax+0.5625,",",bbox@ymin,",",bbox@ymax," ",vname,"_remapped.nc ",fnameout,sep=""))
        
        #garbage collection
        system(paste("rm -f ",vname,"_remapped.nc",sep=""))
        setwd(wd)
      }
    }
  }
}


#loop gcm and scenario
for (sce ggin sce_list) {
  for (gcm in gcm_list) {
    cat("\n...processing rcp=",sce,"and gcm=",gcm,"\n")
    process_isimip_wth(gcm,sce)
  }
}

