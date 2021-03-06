#Julian Ramirez
#eejarv@leeds.ac.uk
#Oct 2010

#This R script computes the EcoCrop suitability index based on a set of parameters

require(rgdal)
require(raster)

makeLogFile <- function(filePathName, climPath, cropname, Gmin, Gmax, Tkmp, Tmin, Topmin, Topmax, Tmax, Rmin, Ropmin, Ropmax, Rmax) {
	con <- file(filePathName, "w")
	writeLines(paste("CLIMATE_FILES:", climPath), con)
	writeLines(paste("CROP:", cropname), con)
	writeLines(paste("GMIN:", Gmin), con)
	writeLines(paste("GMAX:", Gmax), con)
	writeLines(paste("TKMP:", Tkmp), con)
	writeLines(paste("TMIN:", Tmin), con)
	writeLines(paste("TOPMIN:", Topmin), con)
	writeLines(paste("TOPMAX:", Topmax), con)
	writeLines(paste("TMAX:", Tmax), con)
	writeLines(paste("RMIN:", Rmin), con)
	writeLines(paste("ROPMIN:", Ropmin), con)
	writeLines(paste("ROPMAX:", Ropmax), con)
	writeLines(paste("RMAX:", Rmax), con)
	close(con)
}

suitCalc <- function(climPath='', Gmin=90,Gmax=90,Tkmp=0,Tmin=10,Topmin=16,Topmax=25,Tmax=35,Rmin=150,Ropmin=300,Ropmax=400,Rmax=600, outfolder='', cropname='', coincide="T") {
	minAdapt <- 0
	maxAdapt <- 1
	
	#Checking climPath folder for consistency
	if (!file.exists(climPath)) {
		stop("The specified folder where the climate files should be does not exist, please check...")
	}
	#Checking climate files for existence
	for (i in 1:12) {
		if (!file.exists(paste(climPath, "/tmean_", i, ".asc", sep=""))) {
			stop("Error mean temperature for month ", i, ": file does not exist")
		} else if (!file.exists(paste(climPath, "/tmin_", i, ".asc", sep=""))) {
			stop("Error min temperature for month ", i, ": file does not exist")
		} else if (!file.exists(paste(climPath, "/prec_", i, ".asc", sep=""))) {
			stop("Error precipitation for month ", i, ": file does not exist")
		}
	}
	cat("Input climate files verification successful \n")
	
	#Checking parameters for consistency
	#if (class(Gmin) != "numeric") {
	#	stop("Inappropriate class of the Gmin parameter")
	#} else if (class(Gmax) != "numeric") {
	#	stop("Inappropriate class of the Gmax parameter")
	#} else if (class(Tkmp) != "numeric") {
	#	stop("Inappropriate class of the Tkmp parameter")
	#} else if (class(Tmin) != "numeric") {
	#	stop("Inappropriate class of the Tmin parameter")
	#} else if (class(Topmin) != "numeric") {
	#	stop("Inappropriate class of the Topmin parameter")
	#} else if (class(Topmax) != "numeric") {
	#	stop("Inappropriate class of the Topmax parameter")
	#} else if (class(Tmax) != "numeric") {
	#	stop("Inappropriate class of the Tmax parameter")
	#} else if (class(Rmin) != "numeric") {
	#	stop("Inappropriate class of the Rmin parameter")
	#} else if (class(Ropmin) != "numeric") {
	#	stop("Inappropriate class of the Ropmin parameter")
	#} else if (class(Ropmax) != "numeric") {
	#	stop("Inappropriate class of the Ropmax parameter")
	#} else if (class(Rmax) != "numeric") {
	#	stop("Inappropriate class of the Rmax parameter")
	#}
	#Checking parameters for consistency part 2
	if (Gmin > 365) {
		stop("Gmin cannot be greater than 365")
	}
	#Checking if outfolder does exist, and creating it if necessary
	if (!file.exists(outfolder)) {
		dir.create(outfolder, recursive=T)
	}
	
	#Creating the log file
	logFileName <- paste(outfolder, "/", cropname, "-parameters.model", sep="")
	createLog <- makeLogFile(logFileName, climPath, cropname, Gmin, Gmax, Tkmp, Tmin, Topmin, Topmax, Tmax, Rmin, Ropmin, Ropmax, Rmax)
	
	#Creating the stack of the whole list of variables
	climateStack <- stack(stack(paste(climPath, "/tmean_", c(1:12), ".asc", sep="")), stack(paste(climPath, "/tmin_", c(1:12), ".asc", sep="")), stack(paste(climPath, "/prec_", c(1:12), ".asc", sep="")))
	
	#Calculating regression models between Rmin-Ropmin and Ropmax-Rmax
	rainLeftReg <- lsfit(x=c(Rmin,Ropmin), y=c(0,1))
	rainLeftM <- rainLeftReg$coefficients[2]
	rainLeftB <- rainLeftReg$coefficients[1]
	rainRightReg <- lsfit(x=c(Ropmax,Rmax), y=c(1,0))
	rainRightM <- rainRightReg$coefficients[2]
	rainRightB <- rainRightReg$coefficients[1]
	Gavg <- round(mean(c(Gmin, Gmax)) / 30)
	Tkill <- Tkmp + 40
	cat("Growing season is", Gavg, "months \n")
	
	#This is the function that evaluates the suitability in a pixel basis
	suitFun <- function(dataPixel) {
		if(length(which(is.na(dataPixel)))!=0) {
			return(c(NA,NA,NA,NA,NA))
		} else {
			TavDataPixel <- dataPixel[1:12]
			TnDataPixel <- dataPixel[13:24]
			PptDataPixel <- dataPixel[25:36]
			tSuit <- rep(NA, 12)
			pSuit <- rep(NA, 12)
			cumPpt <- rep(NA, 12)
			for (i in 1:12) {
				start.month <- i
				end.month <- i + Gavg - 1
				
				#Temp. iteration
				if (TnDataPixel[i] < Tkill) {
					tSuit[i] <- 0
				} else if (TavDataPixel[i] < Tmin) {
					tSuit[i] <- 0
				} else if (TavDataPixel[i] < Topmin) {
					tSuit[i] <- 1 - ((Topmin - TavDataPixel[i]) * (1 / (Topmin - Tmin)))
				} else if (TavDataPixel[i] < Topmax) {
					tSuit[i] <- 1
				} else if (TavDataPixel[i] < Tmax) {
					tSuit[i] <- (Tmax - TavDataPixel[i]) * (1 / (Tmax - Topmax))
				} else {
					tSuit[i] <- 0
				}
				
				#Ppt growing season
				end.mth.p <- end.month
				if (end.mth.p > 12) {
					end.mth.p <- end.mth.p - 12
					cumPpt[i] <- sum(PptDataPixel[c(start.month:12,1:end.mth.p)])
				} else {
					cumPpt[i] <- sum(PptDataPixel[start.month:end.mth.p])
				}
				
				
				#Precipitation iteration
				if (cumPpt[i] < Rmin) {
					pSuit[i] <- 0
				} else if (cumPpt[i] >= Rmin & cumPpt[i] <= Ropmin) {
					pSuit[i] <- (rainLeftM) * cumPpt[i] + (rainLeftB)
				} else if (cumPpt[i] > Ropmin & cumPpt[i] < Ropmax) {
					pSuit[i] <- 1
				} else if (cumPpt[i] >= Ropmax &  cumPpt[i] <= Rmax) {
					pSuit[i] <- (rainRightM) * cumPpt[i] + (rainRightB)
				} else if (cumPpt[i] > Rmax) {
					pSuit[i] <- 0
				} else {
					pSuit[i] <- NA
				}
			}
			
			#Minimum cumulated temperature and rainfall suitability
			if (coincide == "T") {
        ecotf <- rep(NA, 12)
  			ecopf <- rep(NA, 12)
        finSuit <- rep(NA, 12)
				for (i in 1:12) {
					start.month <- i
					end.month <- i + Gavg - 1
					ecot <- rep(NA, Gavg)
					ecot[1] <- 1
					mthCounter <- 1
					for (j in start.month:end.month) {
						r.end.mth <- j
						if (r.end.mth > 12) {r.end.mth <- r.end.mth - 12}
						r.nxt.mth <- r.end.mth + 1
						
						nxtCounter <- mthCounter + 1
						if (tSuit[r.end.mth] < ecot[mthCounter]) {
							ecot[nxtCounter] <- tSuit[r.end.mth]
						} else {
							ecot[nxtCounter] <- ecot[mthCounter]
						}
						mthCounter <- mthCounter + 1
					}
					ecot <- ecot[which(!is.na(ecot[]))]
					ecopf[i]<-pSuit[start.month]
					ecotf[i] <- min(ecot)
					finSuit[i] <- max(round((ecopf[i] * ecotf[i]) * 100))
				}
        precFinSuit <- round(max(ecopf * 100))
				if (precFinSuit == 0) {precFinGS <- 0} else {precFinGS <- max(which(ecopf == max(ecopf)))}
				tempFinSuit <- round(max(ecotf * 100))
				if (tempFinSuit == 0) {tempFinGS <- 0} else {tempFinGS <- max(which(ecotf == max(ecotf)))}
				finSuit <- max(finSuit)
				res <- c(precFinSuit, tempFinSuit, finSuit, precFinGS, tempFinGS)
			} else {
				ecotf <- rep(NA, 12)
  		  ecopf <- rep(NA, 12)
			  for (i in 1:12) {
				  start.month <- i
				  end.month <- i + Gavg - 1
				  ecot <- rep(NA, Gavg)
				  ecop <- rep(NA, Gavg)
				  ecot[1] <- 1
				  ecop[1] <- 0
				  mthCounter <- 1
				  for (j in start.month:end.month) {
					  r.end.mth <- j
					  if (r.end.mth > 12) {r.end.mth <- r.end.mth - 12}
					  r.nxt.mth <- r.end.mth + 1
					
					  nxtCounter <- mthCounter + 1
					  if (tSuit[r.end.mth] < ecot[mthCounter]) {
						ecot[nxtCounter] <- tSuit[r.end.mth]
					  } else {
						ecot[nxtCounter] <- ecot[mthCounter]
					  }
					
					  if (pSuit[r.end.mth] > ecop[mthCounter]) {
						ecop[nxtCounter] <- pSuit[r.end.mth]
					  } else {
						ecop[nxtCounter] <- ecop[mthCounter]
					  }
					  mthCounter <- mthCounter + 1
				  }
  				ecot <- ecot[which(!is.na(ecot[]))]
  				ecop <- ecop[which(!is.na(ecot[]))]
  				ecotf[i] <- min(ecot)
  				ecopf[i] <- max(ecop)
			  }
  			precFinSuit <- round(max(ecopf * 100))
  			if (precFinSuit == 0) {precFinGS <- 0} else {precFinGS <- max(which(ecopf == max(ecopf)))}
  			tempFinSuit <- round(max(ecotf * 100))
  			if (tempFinSuit == 0) {tempFinGS <- 0} else {tempFinGS <- max(which(ecotf == max(ecotf)))}
  			finSuit <- round((max(ecopf) * max(ecotf)) * 100)
  			res <- c(precFinSuit, tempFinSuit, finSuit, precFinGS, tempFinGS)
			}
			return(res)
		}
	}
	
	
	#Final grid naming and creation
	pSuitName <- paste(outfolder, "/", cropname, "_psuitability.asc", sep="")
	pGSName <- paste(outfolder, "/", cropname, "_pGS.asc", sep="")
	tSuitName <- paste(outfolder, "/", cropname, "_tsuitability.asc", sep="")
	tGSName <- paste(outfolder, "/", cropname, "_tGS.asc", sep="")
	fSuitName <- paste(outfolder, "/", cropname, "_suitability.asc", sep="")
	
	pSuitRaster <- raster(climateStack, 0) #filename(pSuitRaster) <- pSuitName
	pGSRaster <- raster(climateStack, 0) #filename(pGSRaster) <- pGSName
	tSuitRaster <- raster(climateStack, 0) #filename(tSuitRaster) <- tSuitName
	tGSRaster <- raster(climateStack, 0) #filename(tGSRaster) <- tGSName
	fSuitRaster <- raster(climateStack, 0) #filename(fSuitRaster) <- fSuitName
	
	bs <- blockSize(climateStack, n=41, minblocks=2)
	cat("(", bs$n, " chunks) \n", sep="")
	pb <- pbCreate(bs$n, type='text', style=3)
	for (b in 1:bs$n) {
		rowVals <- getValues(climateStack, row=bs$row[b], nrows=bs$nrow[b])
		rasVals <- apply(rowVals, 1, suitFun)
		precVecSuit <- rasVals[1,]
		tempVecSuit <- rasVals[2,]
		finlVecSuit <- rasVals[3,]
		precVecGS <- rasVals[4,]
		tempVecGS <- rasVals[5,]
		rm(rasVals)
		
		iniCell <- 1+(bs$row[b]-1)*ncol(pSuitRaster)
		finCell <- (bs$row[b]+bs$nrow[b]-1)*ncol(pSuitRaster)
		pSuitRaster[iniCell:finCell] <- precVecSuit
		tSuitRaster[iniCell:finCell] <- tempVecSuit
		fSuitRaster[iniCell:finCell] <- finlVecSuit
		pGSRaster[iniCell:finCell] <- precVecGS
		tGSRaster[iniCell:finCell] <- tempVecGS
		
		pbStep(pb, b)
	}
	pbClose(pb)
	pSuitRaster <- writeRaster(pSuitRaster, pSuitName, format='ascii', overwrite=TRUE)
	pGSRaster <- writeRaster(pGSRaster, pGSName, format='ascii', overwrite=TRUE)
	tSuitRaster <- writeRaster(tSuitRaster, tSuitName, format='ascii', overwrite=TRUE)
	tGSRaster <- writeRaster(tGSRaster, tGSName, format='ascii', overwrite=TRUE)
	fSuitRaster <- writeRaster(fSuitRaster, fSuitName, format='ascii', overwrite=TRUE)
	
	return(stack(pSuitRaster, pGSRaster, tSuitRaster, tGSRaster, fSuitRaster))
}
