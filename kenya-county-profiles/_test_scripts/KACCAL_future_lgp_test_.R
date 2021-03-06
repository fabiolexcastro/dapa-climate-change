# Calculating climatic indices by counties in Kenya - Future information first and second season
# KACCAL project
# H. Achicanoy
# CIAT, 2016

source('/mnt/workspace_cluster_8/Kenya_KACCAL/scripts/KACCAL_calc_risk_indices_modified.R')

# Load packages
options(warn=-1)
library(raster)
library(ncdf)
library(ncdf4)
library(maptools)
library(ff)
library(data.table)
library(miscTools)
library(compiler)
library(lubridate)

# Define Kenya counties
countyList <- data.frame(Cluster=c(rep('Cluster 1', 3),
                                   rep('Cluster 2', 4),
                                   rep('Cluster 3', 4),
                                   rep('Cluster 4', 4)),
                         County=c('Kilifi', 'Tana River', 'Garissa',
                                  'Kwale', 'Makueni', 'Taita Taveta', 'Embu',
                                  'Meru', 'Nyeri', 'Nyandarua', 'Nakuru',
                                  'Homa Bay', 'Siaya', 'Busia', 'West Pokot')) # Define counties to analyze by cluster
countyList$Cluster <- as.character(countyList$Cluster)
countyList$County <- as.character(countyList$County)

countyList <- countyList[1,]

periodList <- c('2021_2045', '2041_2065')
rcpList    <- paste("rcp", c(26, 45, 60, 85), sep="")
gcmList    <- c("bcc_csm1_1","bcc_csm1_1_m","csiro_mk3_6_0","gfdl_cm3", "gfdl_esm2g","gfdl_esm2m","ipsl_cm5a_mr","miroc_esm", "miroc_esm_chem","miroc_miroc5","ncc_noresm1_m") # "mohc_hadgem2_es"

# years_analysis <- paste('y', 1981:2005, sep='')
inputDir <- '/mnt/workspace_cluster_8/Kenya_KACCAL/data/bc_quantile_0_05deg_lat'
outputDir <- '/mnt/workspace_cluster_8/Kenya_KACCAL/results/climatic_indices/future'

seasonList <- c('first', 'second')

calc_climIndices <- function(county='Kilifi', season='first'){
  
  cat('\n\n\n*** Processing:', gsub(pattern=' ', replacement='_', county, fixed=TRUE), 'county ***\n\n')
  
  lapply(1:length(periodList), function(j){
    
    cat('Processing period:', periodList[j], '\n')
    
    lapply(1:length(rcpList), function(k){
      
      cat('Processing RCP:', rcpList[k], '\n')
      
      lapply(1:length(gcmList), function(l){
        
        cat('Processing GCM:', gcmList[l], '\n')
        
        indexes <- paste(outputDir, '/', season,'_season/', gcmList[l], '/', periodList[j], '/', rcpList[k], '/', gsub(pattern=' ', replacement='_', county, fixed=TRUE), '_', season,'_season.RData', sep='')
        
        #if(!file.exists(indexes)){
        
        years_analysis <- as.numeric(unlist(strsplit(x=periodList[j], split='_')))
        years_analysis <- years_analysis[1]:years_analysis[2]
        
        countyDir <- paste('/mnt/workspace_cluster_8/Kenya_KACCAL/data/bc_quantile_0_05deg_lat/', gcmList[l], '/', periodList[j], '/', rcpList[k], '/', gsub(pattern=' ', replacement='_', county), sep='')
        if(length(list.files(path=countyDir, recursive=TRUE))==14){
          
          cat('Loading raster mask for:', gsub(pattern=' ', replacement='_', county), '\n')
          countyMask <- raster(paste("/mnt/workspace_cluster_8/Kenya_KACCAL/data/Kenya_counties_rst/", gsub(pattern=' ', replacement='_', county), "_base.tif", sep=""))
          
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          cat('Loading: Soil data\n')
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          
          load(paste('/mnt/workspace_cluster_8/Kenya_KACCAL/data/input_tables/', gsub(pattern=' ', replacement='_', county), '/soil/soil_data.RData', sep=''))
          soil <- soil_data_county; rm(soil_data_county)
          soil <- soil[,c("cellID","lon.x","lat.x","id_coarse","rdepth","d.25","d.100","d.225","d.450","d.800","d.1500","soilcp")]
          names(soil)[2:3] <- c('lon','lat')
          
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          ### CLIMATIC INDICES to calculate
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          
          cat('*** 10. Estimate start of each growing season\n')
          cat('*** 11. Estimate length of each growing season\n')
          
          # 10. GPSV: Stability in start of season
          # 11. LGPM: Length of growing season
          # 12. LGPV: Variability of LGP
          
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          cat('Loading: Solar radiation for complete period\n')
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          
          load(paste(countyDir, '/dswrf/bc_qmap_dswrf_', periodList[j],'.RData', sep=''))
          dswrfAll <- gcmFutBC
          dswrfAll <- as.data.frame(dswrfAll)
          
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          cat('Loading: Daily precipitation for complete period\n')
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          
          load(paste(countyDir, '/prec/bc_qmap_prec_', periodList[j], '.RData', sep=''))
          precAll <- gcmFutBC
          precAll <- as.data.frame(precAll)
          
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          cat('Loading: Maximum temperature for complete period\n')
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          
          load(paste(countyDir, '/tmax/bc_qmap_tmax_', periodList[j], '.RData', sep=''))
          tmaxAll <- gcmFutBC
          tmaxAll <- as.data.frame(tmaxAll)
          
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          cat('Loading: Minimum temperature for complete period\n')
          ### =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= ###
          
          load(paste(countyDir, '/tmin/bc_qmap_tmin_', periodList[j], '.RData', sep=''))
          tminAll <- gcmFutBC
          tminAll <- as.data.frame(tminAll)
          
          ncells <- length(Reduce(intersect, list(tmaxAll[,'cellID'], tminAll[,'cellID'], precAll[,'cellID'], dswrfAll[,'cellID'], soil[,'cellID'])))
          pixelList <- Reduce(intersect, list(tmaxAll[,'cellID'], tminAll[,'cellID'], precAll[,'cellID'], dswrfAll[,'cellID'], soil[,'cellID']))
          
          # Created function
          library(tidyr)
          library(lubridate)
          GSEASProcess <- function(j){ # By pixel
            
            daysList <- Reduce(intersect, list(colnames(tmaxAll[,-c(1:3)]), colnames(tminAll[,-c(1:3)]),
                                               colnames(precAll[,-c(1:3)]), colnames(dswrfAll[,-c(1:3)])))
            
            out_all <- soil[which(soil$cellID==pixelList[j]), c('cellID', 'lon', 'lat')]
            out_all <- do.call("rbind", replicate(length(daysList), out_all, simplify=FALSE))
            out_all$SRAD <- as.numeric(dswrfAll[which(dswrfAll$cellID==pixelList[j]), match(daysList, colnames(dswrfAll))])
            out_all$TMIN <- as.numeric(tminAll[which(tminAll$cellID==pixelList[j]), match(daysList, colnames(tminAll))])
            out_all$TMAX <- as.numeric(tmaxAll[which(tmaxAll$cellID==pixelList[j]), match(daysList, colnames(tmaxAll))])
            out_all$RAIN <- as.numeric(precAll[which(precAll$cellID==pixelList[j]), match(daysList, colnames(precAll))])
            rownames(out_all) <- daysList
            
            soilcp <- soil[which(soil$cellID==pixelList[j]), 'soilcp']
            
            if(!is.na(soilcp)){
              
              watbal_loc <- watbal_wrapper(out_all=out_all, soilcp=soilcp) # If we need more indexes are here
              watbal_loc$TAV <- (watbal_loc$TMIN + watbal_loc$TMAX)/2
              watbal_loc <- watbal_loc[,c('cellID', 'lon', 'lat', 'TAV', 'ERATIO')]
              watbal_loc$GDAY <- ifelse(watbal_loc$TAV >= 6 & watbal_loc$ERATIO >= 0.35, yes=1, no=0)
              
              ### CONDITIONS TO HAVE IN ACCOUNT
              # Length of growing season per year
              # Start: 5-consecutive growing days.
              # End: 12-consecutive non-growing days.
              
              # Run process by year
              lgp_year_pixel <- lapply(1:length(years_analysis), function(k){
                
                # Subsetting by year
                watbal_year <- watbal_loc[year(rownames(watbal_loc))==gsub(pattern='y', replacement='', years_analysis[k]),]
                
                # Calculate sequences of growing and non-growing days within year
                runsDF <- rle(watbal_year$GDAY)
                runsDF <- data.frame(Lengths=runsDF$lengths, Condition=runsDF$values)
                
                # Identify start and extension of each growing season during year
                if(!sum(runsDF$Lengths[runsDF$Condition==1] < 5) == length(runsDF$Lengths[runsDF$Condition==1])){
                  
                  LGP <- 0; LGP_seq <- 0
                  for(i in 1:nrow(runsDF)){
                    if(runsDF$Lengths[i] >= 5 & runsDF$Condition[i] == 1){
                      LGP <- LGP + 1
                      LGP_seq <- c(LGP_seq, LGP)
                      LGP <- 0
                    } else {
                      if(LGP_seq[length(LGP_seq)]==1){
                        if(runsDF$Lengths[i] >= 12 & runsDF$Condition[i] == 0){
                          LGP <- 0
                          LGP_seq <- c(LGP_seq, LGP)
                        } else {
                          LGP <- LGP + 1
                          LGP_seq <- c(LGP_seq, LGP)
                          LGP <- 0
                        }
                      } else {
                        LGP <- 0
                        LGP_seq <- c(LGP_seq, LGP)
                      }
                    }
                  }
                  LGP_seq <- c(LGP_seq, LGP)
                  LGP_seq <- LGP_seq[-c(1, length(LGP_seq))]
                  runsDF$gSeason <- LGP_seq; rm(i, LGP, LGP_seq)
                  LGP_seq <- as.list(split(which(runsDF$gSeason==1), cumsum(c(TRUE, diff(which(runsDF$gSeason==1))!=1))))
                  
                  # Calculate start date and extension of each growing season by year and pixel
                  growingSeason <- lapply(1:length(LGP_seq), function(g){
                    
                    LGP_ini <- sum(runsDF$Lengths[1:(min(LGP_seq[[g]])-1)]) + 1
                    LGP <- sum(runsDF$Lengths[LGP_seq[[g]]])
                    results <- data.frame(cellID=pixelList[j], year=gsub(pattern='y', replacement='', years_analysis[k]), gSeason=g, SLGP=LGP_ini, LGP=LGP)
                    return(results)
                    
                  })
                  growingSeason <- do.call(rbind, growingSeason)
                  growingSeason <- data.frame(cellID = pixelList[j], year = gsub(pattern='y', replacement='', years_analysis[k]), nGSeason = nrow(growingSeason))
                  
                } else {
                  
                  growingSeason <- NULL
                  
                }
                
                return(growingSeason)
                
              })
              
              lgp_year_pixel <- do.call(rbind, lgp_year_pixel); rownames(lgp_year_pixel) <- 1:nrow(lgp_year_pixel)
              return(lgp_year_pixel)
              
            } else {
              return(cat('It is probable that pixel:', pixelList[j], 'is a water source\n'))
            }
            
          }
          library(compiler)
          GSEASProcessCMP <- cmpfun(GSEASProcess)
          
          # Running process for all pixel list
          library(dplyr)
          library(foreach)
          library(doMC)
          registerDoMC(20)
          
          GSEAS <- foreach(j=1:ncells) %dopar% {
            GSEASProcessCMP(j)
          }
          
          GSEAS <- do.call(rbind, GSEAS)
          GSEAS <- GSEAS %>% spread(year, nGSeason)
          
          x <- countyMask
          x[] <- NA
          x[GSEAS$cellID] <- GSEAS$'2041'
          plot(x)
          
          plot(2021:2045, as.numeric(GSEAS[1,-1]), xlab='Year', ylab='Number of growing seasons within year', ylim=c(0, 20), ty='l')
          for(i in 2:nrow(GSEAS)){
            lines(2021:2045, as.numeric(GSEAS[i,-1]))
          }
          
          max(as.matrix(GSEAS[,-1]), na.rm=TRUE)
          min(as.matrix(GSEAS[,-1]), na.rm=TRUE)
          
          #####
          
          # Save all indexes
          clim_indexes <- list(TMEAN=TMEAN, GDD_1=GDD_1, GDD_2=GDD_2, ND_t35=ND_t35,
                               TOTRAIN=TOTRAIN, CDD=CDD, P5D=P5D, P_95=P_95, NDWS=NDWS)
          
          # Save according to season
          if(season == 'first'){
            seasonDir <- paste(outputDir, '/first_season/', gcmList[l], '/', periodList[j], '/', rcpList[k], sep='')
            if(!dir.exists(seasonDir)){dir.create(seasonDir, recursive=TRUE)}
            save(clim_indexes, file=paste(seasonDir, '/', gsub(pattern=' ', replacement='_', county, fixed=TRUE), '_first_season.RData', sep=''))
          } else {
            if(season == 'second'){
              seasonDir <- paste(outputDir, '/second_season/', gcmList[l], '/', periodList[j], '/', rcpList[k], sep='')
              if(!dir.exists(seasonDir)){dir.create(seasonDir, recursive=TRUE)}
              save(clim_indexes, file=paste(seasonDir, '/', gsub(pattern=' ', replacement='_', county, fixed=TRUE), '_second_season.RData', sep=''))
            }
          }
          
        } else {
          
          cat('Process failed. Climatic information is not processed yet.\n')
          
        }
        
        # } else {
        #   
        #   cat('Process has been done before. It is not necessary recalculate.\n')
        #   
        # }
        
      })
    })
  })
  
  return(cat('Process done.\n'))
  
}

countyList <- countyList[2,]

lapply(1:length(seasonList), function(j){
  lapply(1:nrow(countyList), function(i){
    calc_climIndices(county=countyList$County[i], season=seasonList[j])
  })
})
