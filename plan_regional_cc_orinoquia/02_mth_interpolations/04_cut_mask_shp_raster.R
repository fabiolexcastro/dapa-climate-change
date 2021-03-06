## For prec, tmin, tmax, tmean

require(raster)
require(maptools)
require(rgdal)

dirbase <- "X:/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/01-datos_clima/baseline/llanos/average"
mask <- raster("X:/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/01-datos_clima/_masks/mask_v1.tif")

varList <- c("rhum") #,"prec", "tmax", "tmin")
outDir <- paste(dirbase, sep="")
if (!file.exists(outDir)) {dir.create(outDir)}

setwd(dirbase)

# for(rs in rsList){
for (var in varList){
  
  rsStk <- stack(paste0(dirbase, "/", var, "_", 1:12, ".asc"))
  
  if (!file.exists(paste0(outDir, "/", var, "_", 12, ".tif"))) {
    
    rsCrop <- crop(rsStk, extent(mask))
    rsMask <- mask(rsCrop, mask)
    
    if (var == "prec"){
      rsMask <- round(rsMask, digits = 0)
    } else if (var == "rhum"){
      rsMask <- round(rsMask * 100, digits = 0)
    } else {
      rsMask <- round(rsMask * 10, digits = 0)
    }

    for (i in 1:12){
      
      oTif <- paste0(outDir, "/", var, "_",i, ".tif")
      tifWrite <- writeRaster(rsMask[[i]], oTif, format="GTiff", overwrite=T, datatype='INT2S')
      cat(paste0(" ", var, "_",i, " cut done\n"))
      
    }
  }
}



### Cut bioclimatic variables
# 
# require(raster)
# require(maptools)
# require(rgdal)
# 
# dirbase <- "X:/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/01-datos_clima/baseline/llanos/average"
# mask <- raster("X:/ALPACAS/Plan_Regional_de_Cambio_Climatico_Orinoquia/01-datos_clima/_masks/mask_v1.tif")

varList <- c("bio")
outDir <- paste(dirbase, sep="")
if (!file.exists(outDir)) {dir.create(outDir)}

setwd(dirbase)

# for(rs in rsList){
for (var in varList){
  
  if (!file.exists(paste0(outDir, "/", var, "_", 19, ".tif"))) {
    
    notrans <- c(3, 12, 13, 14, 15, 16, 17, 18, 19)
    
    for (i in 1:19){
      
      rsStk <- raster(paste0(dirbase, "/", var, "_", i, ".asc"))
      rsCrop <- crop(rsStk, extent(mask))
      rsMask <- mask(rsCrop, mask)
      
      if (i %in% notrans){
        rsMask <- round(rsMask, digits = 0)
      } else {
        rsMask <- round(rsMask * 10, digits = 0)
      }
      
      oTif <- paste0(outDir, "/", var, "_",i, ".tif")
      tifWrite <- writeRaster(rsMask, oTif, format="GTiff", overwrite=T, datatype='INT2S')
      cat(paste0(" ", var, "_",i, " cut done\n"))
      
    }
  }
}





