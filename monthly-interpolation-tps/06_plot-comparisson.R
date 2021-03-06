# Load libraries
require(raster)
require(rasterVis)
require(maptools)
require(rgdal)

## 01-Baseline Interpolated surfaces plots (Re-interpolation WorldCLim)

dirbase <- "D:/CIAT/Projects/col-usaid/02_monthly_interpolation/outputs_complemented"
periods <- c("1976-1985", "1980-2010", "1986-1995", "1996-2005", "2006-2015")
oDir <- "D:/CIAT/Projects/col-usaid/02_monthly_interpolation/performance"
if (!file.exists(oDir)) {dir.create(oDir, recursive=T)}
mask <- readOGR("D:/CIAT/Projects/col-usaid/02_monthly_interpolation/region/mask/ris_adm0.shp", layer= "ris_adm0")
geotopo <- readOGR("D:/CIAT/Projects/col-usaid/02_monthly_interpolation/region/mask/ecotopo.shp", layer= "ecotopo")
varList <- c("prec","tmax", "tmin") 
id <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

for (period in periods){
  
  iDir <- paste0(dirbase, "/", period, "/average")

  for (var in varList){
      
      stk_crop <- stack(paste0(iDir, "/", var, "_", 1:12, ".tif"))
      # stk_crop <- mask(crop(stk, extent(mask)), mask)
      
      if (var == "prec"){
  
        stk_crop[which(stk_crop[]>800)]=800
        
        plot <- setZ(stk_crop, id)
        names(plot) <- id
        
        zvalues <- seq(0, 800, 50) # Define limits
        myTheme <- BuRdTheme() # Define squeme of colors
        myTheme$regions$col=colorRampPalette(c("snow", "blue", "magenta"))(length(zvalues)-1) # Set new colors
        myTheme$strip.border$col = "white" # Eliminate frame from maps
        myTheme$axis.line$col = 'white' # Eliminate frame from maps
        # myTheme=rasterTheme(region=brewer.pal('Blues', n=9))  
        
      } else if ( var == "rhum") {
        
        stk_crop <- stk_crop
        stk_crop[which(stk_crop[]>100)]=100
        stk_crop[which(stk_crop[]<60)]=60
        
        plot <- setZ(stk_crop, id)
        names(plot) <- id
        zvalues <- seq(60, 100, 5)
        # zvalues <- c(-10, -5, 0, 5, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40)
        myTheme <- BuRdTheme()
        myTheme$regions$col=colorRampPalette(c("burlywood","snow", "deepskyblue", "darkcyan"))(length(zvalues)-1) # Set new colors
        myTheme$strip.border$col = "white"
        myTheme$axis.line$col = 'white'
        # myTheme=rasterTheme(region=brewer.pal('YlOrRd', n=9))  
        
      } else {
        
        stk_crop <- stk_crop / 10
        stk_crop[which(stk_crop[]< (-8) )]= (-8)
        stk_crop[which(stk_crop[]>36)]= 36
        
        plot <- setZ(stk_crop, id)
        names(plot) <- id
        zvalues <- seq(-8, 36, 2)
        # zvalues <- c(-8, -4, 0, 4, 8, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 36)
        myTheme <- BuRdTheme()
        myTheme$regions$col=colorRampPalette(c("darkblue", "snow", "yellow", "orange", "red", "darkred"))(length(zvalues)-1)
        myTheme$strip.border$col = "white"
        myTheme$axis.line$col = 'white'
        # myTheme=rasterTheme(region=brewer.pal('YlOrRd', n=9))  
  
      }
      
    tiff(paste(oDir, "/months_", period, "_",var, ".tif", sep=""), width=1000, height=1200, pointsize=8, compression='lzw',res=100)
        
      print(levelplot(plot, at = zvalues, scales = list(draw=FALSE),  xlab="", ylab="", par.settings = myTheme, colorkey = list(space = "bottom")) + layer(sp.polygons(mask)) + layer(sp.polygons(geotopo)))
    
    dev.off()
    
  } 
}





# Load libraries
require(raster)
require(rasterVis)
require(maptools)
require(rgdal)

## 01-Baseline Interpolated surfaces plots (Re-interpolation WorldCLim)

dirbase <- "D:/CIAT/Projects/col-usaid/02_monthly_interpolation/outputs_complemented"
periods <- c("1976-1985", "1980-2010", "1986-1995", "1996-2005", "2006-2015")
oDir <- "D:/CIAT/Projects/col-usaid/02_monthly_interpolation/performance"
if (!file.exists(oDir)) {dir.create(oDir, recursive=T)}
mask <- readOGR("D:/CIAT/Projects/col-usaid/02_monthly_interpolation/region/mask/ris_adm0.shp", layer= "ris_adm0")
geotopo <- readOGR("D:/CIAT/Projects/col-usaid/02_monthly_interpolation/region/mask/ecotopo_prj.shp", layer= "ecotopo_prj")

varList <- c("prec", "tmean", "dtr") # "prec", 
# id <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
id <- c("djf", "mam", "jja", "son")

for (period in periods){
  
  iDir <- paste0(dirbase, "/", period, "/average")
  
  for (var in varList){
    
    stk_crop <- stack(paste0(iDir, "/", var, "_", id, ".tif"))
    # stk_crop <- mask(crop(stk, extent(mask)), mask)
    
    if (var == "prec"){
      
      stk_crop[which(stk_crop[]>1500)]=1500
      
      plot <- setZ(stk_crop, id)
      names(plot) <- toupper(id)
      
      zvalues <- seq(0, 1500, 100) # Define limits
      myTheme <- BuRdTheme() # Define squeme of colors
      myTheme$regions$col=colorRampPalette(c("orange", "snow", "blue", "darkblue","magenta"))(length(zvalues)-1) # Set new colors
      myTheme$strip.border$col = "white" # Eliminate frame from maps
      myTheme$axis.line$col = 'white' # Eliminate frame from maps
      # myTheme=rasterTheme(region=brewer.pal('Blues', n=9))  
      
    } else if ( var == "rhum") {
      
      stk_crop <- stk_crop
      stk_crop[which(stk_crop[]>100)]=100
      stk_crop[which(stk_crop[]<60)]=60
      
      plot <- setZ(stk_crop, id)
      names(plot) <- toupper(id)
      zvalues <- seq(60, 100, 5)
      # zvalues <- c(-10, -5, 0, 5, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40)
      myTheme <- BuRdTheme()
      myTheme$regions$col=colorRampPalette(c("burlywood","snow", "deepskyblue", "darkcyan"))(length(zvalues)-1) # Set new colors
      myTheme$strip.border$col = "white"
      myTheme$axis.line$col = 'white'
      # myTheme=rasterTheme(region=brewer.pal('YlOrRd', n=9))  
      
    } else if ( var == "dtr") {
      
      stk_crop <- stk_crop
      stk_crop <- stk_crop / 10
      stk_crop[which(stk_crop[]>20)]= 20
      
      plot <- setZ(stk_crop, id)
      names(plot) <- toupper(id)
      zvalues <- seq(0, 20, 2)
      # zvalues <- c(-10, -5, 0, 5, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40)
      myTheme <- BuRdTheme()
      myTheme$regions$col=colorRampPalette(c("snow", "yellow", "orange", "red", "darkred"))(length(zvalues)-1) # Set new colors
      myTheme$strip.border$col = "white"
      myTheme$axis.line$col = 'white'
      # myTheme=rasterTheme(region=brewer.pal('YlOrRd', n=9))  
      
      
    } else {
      
      stk_crop <- stk_crop / 10
      stk_crop[which(stk_crop[]< (-8) )]= (-8)
      stk_crop[which(stk_crop[]>36)]= 36
      
      plot <- setZ(stk_crop, id)
      names(plot) <- toupper(id)
      zvalues <- seq(-8, 36, 2)
      # zvalues <- c(-8, -4, 0, 4, 8, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 36)
      myTheme <- BuRdTheme()
      myTheme$regions$col=colorRampPalette(c("darkblue", "snow", "yellow", "orange", "red", "darkred"))(length(zvalues)-1)
      myTheme$strip.border$col = "white"
      myTheme$axis.line$col = 'white'
      # myTheme=rasterTheme(region=brewer.pal('YlOrRd', n=9))  
      
    }
    
    tiff(paste(oDir, "/seasons_", period, "_",var, ".tif", sep=""), width=1200, height=400, pointsize=8, compression='lzw',res=100)
    
    print(levelplot(plot, at = zvalues, scales = list(draw=FALSE), layout=c(4, 1), xlab="", ylab="", par.settings = myTheme, colorkey = list(space = "bottom")) + layer(sp.polygons(mask)) + layer(sp.polygons(geotopo, fill='white', alpha=0.3)))
    
    dev.off()
    
  } 
}



