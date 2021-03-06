#Julian Ramirez-Villegas
#UoL / CCAFS
#Feb 2014
# stop("!")
# Modified by Carlos Navarro May 2015

#all data at: /nfs/a101/eejarv/quest-for-robustness/data/meteorology/wfd_data
#WFD:
#Tmax: Tmax_daily_WFD
#Tmin: Tmin_daily_WFD
#Prec: Rainf_daily_WFD_GPCC
#Srad: SWdown_daily_WFD

#WFDEI:
#Tmax: Tmax_daily_WFDEI
#Tmin: Tmin_daily_WFDEI
#Prec: Rainf_daily_WFDEI_GPCC
#Srad: SWdown_daily_WFDEI

#load libraries
library(sp); library(raster); library(rgdal); library(maptools); library(ncdf)

#input directories
# wd <- "S:/observed/gridded_products/wfd/daily/nc-files/_primary_files"
# oDir <- "S:/observed/gridded_products/wfd/daily/nc-files"
wd <-  "/mnt/data_cluster_4/observed/gridded_products/wfdei/daily/nc-files/_primary_files"
oDir <- "/home/cnavarro/wfdei/" 

if (!file.exists(oDir)) {dir.create(oDir)}

# Get a list of month with and withour 0 in one digit numbers
mthList <- c(1:12)
mthListMod <- c(paste(0,c(1:9),sep=""),paste(c(10:12)))
mthMat <- as.data.frame(cbind(mthList, mthListMod))
names(mthMat) <- c("Mth", "MthMod")

#details
var_list <- c("Rainf","SWdown","Tmax","Tmin")
dst_list <- c("WFD","WFDEI")
wfdei_yrs <- c(1979:2010)
#wfdei_yrs <- c(1979:2012)
wfd_yrs <- c(1950:2001)

#function to process all years and months of a variable and dataset
process_wfd_wth <- function(dataset,vname) {
  
  cat("\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n")
  cat("\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\n")
  cat("\n...processing",dataset,"and",vname,"\n")
  
  bvname <- vname
  if (vname == "Rainf") {suffix <- paste("_daily_",dataset,"_GPCC",sep="")} else {suffix <- paste("_daily_",dataset,sep="")}
  if (dataset == "WFDEI") {if (vname == "Tmax" | vname == "Tmin") {bvname <- "Tair"}}
  
  if (vname == "Rainf") {
    vunits <- "kg m-2 s-1"
    varmod <- "prec"
  } else if (vname == "SWdown") {
    vunits <- "W m-2"
    varmod <- "srad"
  } else {
    vunits <- "K"
    varmod <- tolower(vname)
  }
  
  idataDir <- paste(wd,"/",vname,suffix,sep="")
  odataDir <- paste(oDir,"/",vname,suffix,sep="")
  if (!file.exists(odataDir)) {dir.create(odataDir, recursive=T)}
  
  years <- get(paste(tolower(dataset),"_yrs",sep=""))
  
  
  ts <- paste0(varmod, "_daily_ts_", years[1], "_", years[length(years)], ".nc", sep="")
  if (!file.exists(paste(odataDir,"/", ts))) {
    
    #loop years and months
    for (yr in years) {
      
      for (mth in 1:12) {
        
        mthMod <- paste((mthMat$MthMod[which(mthMat$Mth == mth)]))
        
        cat("...processing year=",yr,"and month=",mth,"\n")
        tmth <- sprintf("%1$02d",mth)
        
        fname <- paste(vname,suffix,"_",yr,tmth,".nc",sep="")
        
        if (!file.exists(paste(odataDir,"/",fname,sep=""))) {
          #read netcdf using ncdf package
          setwd(idataDir)
          nc <- open.ncdf(fname)
          ncdata <- get.var.ncdf(nc,nc$var[[bvname]]) #get data from nc connection
          brs <- raster(nrow=360,ncol=720,xmn=-180,xmx=180,ymn=-90,ymx=90) #base raster
          if (dataset == "WFDEI") {nt <- dim(ncdata)[3]} else {nt <- ncol(ncdata)}
          
          #create stack
          stk <- c()
          for (i in 1:nt) {
            
            rs <- brs
            if (dataset == "WFD") {
              rs[as.numeric(nc$var[[bvname]]$dim[[1]]$vals)] <- ncdata[,i]
              #             stk <- c(stk,rotate(rs))
              stk <- c(stk,rs)
            } else {
              tdata <- t(ncdata[,,i]); tdata[which(tdata[] == 1.e20)] <- NA
              rs[] <- t(ncdata[,,i]) #tdata
              rs[which(rs[] >= 1.e20)] <- NA
              # stk <- c(stk,rotate(flip(rs,direction="y")))
              stk <- c(stk, flip(rs, direction="y"))
            }
          }
          
          nc <- close.ncdf(nc)
          
          #dimension definitions
          dimX <- dim.def.ncdf("lon","degrees_east",seq(-179.75,179.75,by=0.5))
          dimY <- dim.def.ncdf("lat","degrees_north",seq(-89.75,89.75,by=0.5))
          dimT <- dim.def.ncdf( "time", "days", 1:nt, unlim=FALSE)
          
          #create variable definitions
          mv <- 1.e20
          var3d <- var.def.ncdf(vname,vunits,list(dimX,dimY,dimT),mv,prec="single")
          
          #create file
          nc <- create.ncdf(paste(odataDir,"/",vname,"_rewritten.nc",sep=""), list(var3d))
          for (i in 1:nt) {
            data2d <- flip(stk[i][[1]],"y")[]
            put.var.ncdf(nc, var3d, data2d, start=c(1,1,i), c(-1,-1,1))
          }
          nc <- close(nc)
          
          setwd(odataDir)
          system(paste("cdo -s -settaxis,", yr, "-", tmth, "-01,00:00:00,1day ", vname,"_rewritten.nc ", fname, sep=""))
          
          #garbage collection
          file.remove(paste0(vname,"_rewritten.nc"))
          #           system(paste("rm -f ",vname,"_rewritten.nc",sep=""))
          setwd(wd)
          
          
        } else {
          cat("...processed year=",yr,"and month=",mth,"\n")
        }
        
      }
      
    }
    
    ncList <- list.files(odataDir, pattern=paste0(vname,suffix, "_*"),full.names = FALSE)
    
    setwd(odataDir)
    
    cat(paste0("\nMerging ", vname, suffix, "\n"))
    system(paste("cdo -s mergetime ", paste(ncList, collapse=" "), " ", odataDir, "/", ts, sep=""))
    
    ## Remove intial files
    #     for (nc in ncList){system(paste("rm -f ", odataDir, "/", nc, sep=""))}
    
    cat(paste0("\nMerging ", vname, suffix, " done\n"))
    
    
  } else {
    
    cat(paste0("\nMerging ", vname, suffix, " done\n"))
    
  }
  
}


# 
# #loop through datasets and variables
#for (dataset in dst_list) {
dataset <- dst_list[2]

for (vname in var_list) { 
  process_wfd_wth(dataset,vname)
}
#}
