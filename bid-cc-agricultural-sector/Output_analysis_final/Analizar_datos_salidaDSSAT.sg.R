#Visualize DSSAT runs

#Load libraries
library(Hmisc)
library(raster)
library(ggplot2)
library(reshape)
library(RColorBrewer)

#Results directory
# path.res = 'D:/BID/Resultados_DSSAT/'  #results directory
# path.root = 'D:/BID/'  #root path
path.res = "Z:/12-Resultados/"; #'D:/BID/Resultados_DSSAT/'  #results directory
path.root = "Z:/"; #'D:/BID/'  #root path

#cultivos
cultivos = c('maiz','arroz','soya')
cultivos.en = c('Maize','Rice','Soybeans')
# c=1  #maize
# material = 'IB0011_XL45'
c=2  #rice
material = 'IR72'
# c=3  #soy
# material = 'BRS-Tracaja'

#set map coordinates & dot size
xlim.c=c(-116,-35)
ylim.c=c(-54,32)
cex.c = 0.5
subset=F  #turn on subsetting by region?

#Load pixel id's & maps
eval(parse(text=paste('load("',path.root,'08-Cells_toRun/matrices_cultivo/',cultivos.en[c],'_riego.Rdat")',sep='')))
eval(parse(text=paste('load("',path.root,'08-Cells_toRun/matrices_cultivo/',cultivos.en[c],'_secano.Rdat")',sep='')))
eval(parse(text=paste('Map_LatinAmerica<-shapefile("',path.root,'03-Map_LatinAmerica/Latino_America.shp")',sep='')))

#Subset by country or FPU
ind_sub.r = which(crop_riego$country=='Colombia')
ind_sub.s = which(crop_secano$country=='Colombia')
if (subset==T) {
  xlim.c=c(-79,-67)  #override map coordinates
  ylim.c=c(-2,13)
  cex.c=2
}

#get list of climate models
models = read.table(paste(path.root,'/_documentos/ModelosGCM.csv',sep=''),header=T,sep=',',stringsAsFactors=F)
#models = data.frame(models[-c(3,8),],stringsAsFactors=F)  #get rid of models 2 and 7 for now (missing data)
models = rbind(models,'WFD')
colnames(models) = 'Models'  #hack for now

#load, unlist and extract yield data to arrays (gridcells x years x models)
#initialize arrays
yld_secano = array(NA,dim=c(dim(crop_secano)[1],30,dim(models)[1]))  #10 GCM's + baseline
yld_riego = array(NA,dim=c(dim(crop_riego)[1],30,dim(models)[1]))

for (m in 1:(dim(models)[1]))  {
  
  print(m)
  if (m==dim(models)[1])  {
    #Load & extract baseline data from list
    load(paste(path.res,cultivos[c],'/1971-1998/siembra_2s/_',material,'_Secano.Rdat',sep=''))
    Run.secano = Run
    load(paste(path.res,cultivos[c],'/1971-1998/_',material,'_Riego.Rdat',sep=''))
    Run.riego = Run
  } else{    
    #Load future yields from models
    load(paste(path.res,cultivos[c],'/2021-2048/_',material,'_Secano',models[m,],'.Rdat',sep=''))
    Run.secano = Run
    load(paste(path.res,cultivos[c],'/2021-2048/_',material,'_Riego',models[m,],'.Rdat',sep=''))
    Run.riego = Run
  }
  
  #unlist everything into matrices
  secano = array(NA,dim=c(length(Run.secano),30))  #initialize arrays
  for (j in 1:length(Run.secano))  {
    secano[j,1:length(Run.secano[[j]])] = Run.secano[[j]]
  }
  riego = array(NA,dim=c(length(Run.riego),30))
  for (j in 1:length(Run.riego))  {
    riego[j,1:length(Run.riego[[j]])] = Run.riego[[j]]
  }
  
  #place results in array
  yld_secano[,,m] = secano
  yld_riego[,,m] = riego
  
}

#Subset yields by country/FPU
if (subset==T)  {
  yld_riego = yld_riego[ind_sub.r,,]
  yld_secano = yld_secano[ind_sub.s,,]
  crop_riego = crop_riego[ind_sub.r,]
  crop_secano = crop_secano[ind_sub.s,]
}

#put NA for now in 2026 for MRI_CGCM3 (until problem with climate data identified)
# yld_secano[,6,7] = NA
# yld_riego[,6,7] = NA

#Graph results
data_seq = quantile(c(yld_riego,yld_secano),seq(0,1,.05),na.rm=T)
data_seq = c(0,data_seq[which(data_seq>0)[1]:length(data_seq)])  #get rid of repeating zeros
col_pal = colorRampPalette(c('darkblue','orange'))(length(data_seq))
par(mai=c(0.5,0.5,0.5,0.5))
models = rbind(models,'Multi-model average')
p=dim(models)[1]

#interannual averages for each model
par(ask=T)  #loop through plots, pausing for each one
pixels = 'riego'  #riego o secano (which pixels to plot)
for (m in 10:p) {
  if (m<=(p-1))  {
    eval(parse(text=paste('promedio = apply(yld_',pixels,'[,,m],1,mean,na.rm=T)',sep='')))  #average in zeros??  
  }  else{
    eval(parse(text=paste('promedio = apply(yld_',pixels,'[,,1:(p-2)],1,mean,na.rm=T)',sep='')))  #average all GCM's 
  }
  
  cols = col_pal[cut(promedio,data_seq,include.lowest=T)]
  cols[which(promedio==0)]='#FF1493'  #poner zero como rosada
  plot(Map_LatinAmerica,xlim=xlim.c,ylim=ylim.c)
  eval(parse(text=paste('points(crop_',pixels,'[,1:2], col = cols, pch=16, cex=cex.c)',sep='')))
  title(paste(cultivos[c],' (',pixels,'): ',models[m,],sep='')) 
}

#Same plots with ggplot

#limits2 = round(limits/1000)*1000; limits2 = seq(limits2[1],limits2[2],by=1000)
Map_LatinAmerica1<- fortify(Map_LatinAmerica)
treat = c('riego','secano')  #riego o secano (which to plot)
treat.en = c('Irrigated','Rainfed')
models = rbind(models,'Percent Change','Change_sd')
#par(mfrow=c(1,3))  #to make various subplots

#Calculate multi-model mean, % changes, and changes relative to sd
wfd.r = apply(yld_riego[,,(p-1)],1,mean,na.rm=T)
wfd.s = apply(yld_secano[,,(p-1)],1,mean,na.rm=T)
mmm.r = apply(yld_riego[,,1:(p-2)],1,mean,na.rm=T)
mmm.s = apply(yld_secano[,,1:(p-2)],1,mean,na.rm=T)

pct.ch.r = (mmm.r-wfd.r)/wfd.r*100
pct.ch.r[which(wfd.r==0|mmm.r==0)] = NA  #set pixels with 0 yield to NA
pct.ch.s = (mmm.s-wfd.s)/wfd.s*100
pct.ch.s[which(wfd.s==0|mmm.s==0)] = NA

ch.sd.r = (mmm.r-wfd.r)/apply(yld_riego[,,(p-1)],1,sd,na.rm=T)
ch.sd.r[which(wfd.r==0|mmm.r==0)] = NA  #set pixels with 0 yield to NA
ch.sd.s = (mmm.s-wfd.s)/apply(yld_secano[,,(p-1)],1,sd,na.rm=T)
ch.sd.s[which(wfd.s==0|mmm.s==0)] = NA

for (t in 1:2)  {  #loop through riego/ secano
  print(t)
  for (m in (p-1):(p+2))  {
    
    #multi-annual means per model
    if (m<=(p-1))  {
      eval(parse(text=paste('promedio = apply(yld_',treat[t],'[,,m],1,mean,na.rm=T)',sep='')))  #average in zeros??  
    }  else{  if(m==p) {  #multi-model mean
        eval(parse(text=paste('promedio = mmm.',substr(treat[t],1,1),sep='')))
        }  else{ if(m==(p+1)) {  #% change
          eval(parse(text=paste('promedio = pct.ch.',substr(treat[t],1,1),sep='')))
        }  else{  #change relative to sd
          eval(parse(text=paste('promedio = ch.sd.',substr(treat[t],1,1),sep='')))
        }
      }
    }
    
    if(m<=p)  {  #for models
      promedio[promedio==0] = NA  #set 0 values to NA
      limits2 = quantile(c(yld_riego,yld_secano),c(.01,.99),na.rm=T)
      promedio[which(promedio<limits2[1] & promedio>0)] = limits2[1]  #reset end points of data
      promedio[which(promedio>limits2[2])] = limits2[2]
      
      eval(parse(text=paste("df = data.frame(Long=crop_",treat[t],"[,1],Lat=crop_",treat[t],"[,2],yield=promedio)",sep='')))
      color_scale = colorRampPalette(c('red','gold2','forestgreen'), space="rgb")(25) 
      labs2 = 'Yield \n(Kg/ha)'
      }  else{
        #for pct.ch or ch.sd
        if (m==(p+1)) {dat = c(pct.ch.r,pct.ch.s)}  else{dat = c(ch.sd.r,ch.sd.s)}
        limits2 = quantile(dat[dat<0],c(.025),na.rm=T)  
        limits2 = c(limits2,-1*limits2)  #set positive equal to opposite of negative
        promedio[promedio<limits2[1]] = limits2[1]  #reset end points
        promedio[promedio>limits2[2]] = limits2[2]
        eval(parse(text=paste("df = data.frame(Long=crop_",treat[t],"[,1],Lat=crop_",treat[t],"[,2],yield=promedio)",sep='')))
        color_scale = colorRampPalette(c('red','white','forestgreen'), space="rgb")(15)
        labs2 = ''
      }
        
    y=ggplot() +
      geom_polygon( data=Map_LatinAmerica1, aes(x=long, y=lat, group = group),colour="white", fill="white" )+
      geom_path(data=Map_LatinAmerica1, aes(x=long, y=lat, group=group), colour="black", size=0.25)+
      coord_equal() +
      geom_raster(data=df, aes(x=Long, y=Lat,fill=yield))+
      ggtitle(paste(capitalize(cultivos.en[c]),' (',treat.en[t],'): \n',models[m,],sep=''))+
      scale_fill_gradientn(colours=color_scale,limits=limits2,na.value = "grey50")+ # limits ,breaks=as.vector(limits),labels=as.vector(limits),limits=as.vector(limits)
      theme_bw()+
      labs(fill=labs2)+
      theme(panel.grid.major.x = element_blank(),
            panel.grid.minor.x = element_blank(),
            panel.grid.major.y = element_blank(),
            panel.grid.minor.y = element_blank(),
            axis.text.x = element_blank(),
            axis.text.y = element_blank(),
            axis.title.x = element_blank(),
            axis.title.y = element_blank(),
            legend.text = element_text(size=14),
            legend.title = element_text(face="bold",size=14),
            legend.background = element_blank(),
            legend.key = element_blank(),
            plot.title = element_text(face="bold", size=18),
            panel.border = element_blank(),
            axis.ticks = element_blank())
    ggsave(filename=paste(path.root,"_documentos/graficas/",cultivos[c],"_",treat[t],"_",material,"_",models[m,],".png", sep=""), plot=y, width=5, height=5, dpi=400,scale=1.5)
    #ggsave(filename=paste(path.root,"resultados_graficas/",cultivos[c],"_",treat[t],"_",material,"_",models[m,],".png", sep=""), plot=y, width=5, height=4, dpi=400)
  }
}  


# %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% %

#check for 0's
riego_zero = array(NA,dim=c(30,(p-1)))
secano_zero = array(NA,dim=c(30,(p-1)))
for (m in 1:(p-1))  {
  for (j in 1:30)  {
    riego_zero[j,m] = sum(yld_riego[,j,m]==0)
    secano_zero[j,m] = sum(yld_secano[,j,m]==0)
  }
}
riego_zero2 = apply(riego_zero,2,mean,na.rm=T)/dim(yld_riego)[1]*100
secano_zero2 = apply(secano_zero,2,mean,na.rm=T)/dim(yld_secano)[1]*100
names(riego_zero2) = models$Models[1:(p-1)]
names(secano_zero2) = models$Models[1:(p-1)]

#barplot of % failures in future vs. WFD
par(mai=c(1.25,1.25,0.5,0.5))
par(ask=T)
for (t in 1:2)  {  #riego, secano
  eval(parse(text=paste("barplot(",treat[t],"_zero2[1:(p-2)],xaxt='n',ylim=c(0,35),ylab='% Crop Failures')",sep='')))
  eval(parse(text=paste("abline(h=",treat[t],"_zero2[(p-1)],col='red',lty=2,lwd=2)",sep='')))
  eval(parse(text=paste("abline(h=mean(",treat[t],"_zero2[1:(p-2)],na.rm=T),lty=2,lwd=2.5)",sep='')))
  title(paste(cultivos.en[c],' (',treat.en[t],')',sep=''))
  text(x=seq(1,p,1.2),y=-1,cex=1,labels = models$Models[1:(p-2)], xpd=TRUE, srt=40, pos=2)
  legend('topright',c('GCMs - future','Baseline period','Multi-model mean'),bty='n',col=c('grey','red','black'),pch=c(15,-1,-1),lty=c(0,2,2),lwd=c(0,2,2.5))
}

#Calculate overall mean yield changes for entire region (then sub-regions)
#load physical area from SPAM to weight yield changes

#Calculate weighted averages by model & compare to WFD
area.riego = replicate(28,crop_riego$riego.area)
area.secano = replicate(28,crop_secano$secano.area)
regions= c('MEX','CEN','AND','BRA','SUR')

#find areas where WFD consistently failing and discard these from aggregation
zeros.wfd.r = apply(yld_riego[,,(p-1)],1,function(x) sum(x==0,na.rm=T))
zeros.wfd.s = apply(yld_secano[,,(p-1)],1,function(x) sum(x==0,na.rm=T))

#initialize arrays
yld.ag.r = array(NA,dim=c(8,6))  #8 indicators x 6 regions
yld.ag.s = array(NA,dim=c(8,6))  

for (j in 1:6)  {  #5 regions + all
  for (t in 1:2)  {  #loop through riego/ secano
    
    #subset regions
    if (j<=5) {eval(parse(text=paste("ind.reg = which(crop_",treat[t],"$Region==regions[j] & zeros.wfd.",substr(treat[t],1,1),"<=14)",sep='')))
               }   else{
                 eval(parse(text=paste("ind.reg = which(zeros.wfd.",substr(treat[t],1,1),"<=14)",sep='')))
               }
    
    if (length(ind.reg)>1)  {  #at least 2 pixels
      
      mean.ylds = mat.or.vec((p-1),28)  #models x years
      for (m in 1:(p-1))  {  
        for (y in c(1:5,7:28))  {   #take out 2007 for now!
          eval(parse(text=paste("mean.ylds[m,y] = sum(yld_",treat[t],"[ind.reg,y,m]*area.",treat[t],"[ind.reg,y])/sum(area.",treat[t],"[ind.reg,y])",sep=''))) 
        }    
      }
      mean.ylds = apply(mean.ylds,1,mean)  #take inter-annual mean
      
      wfd = mean.ylds[p-1]  #WFD
      mmm = mean(mean.ylds[1:(p-2)],na.rm=T)  #multi-model mean
      eval(parse(text=paste("yld.ag.",substr(treat[t],1,1),"[1,j] = wfd",sep='')))
      eval(parse(text=paste("yld.ag.",substr(treat[t],1,1),"[2,j] = mmm",sep='')))
      eval(parse(text=paste("yld.ag.",substr(treat[t],1,1),"[3,j] = (mmm - wfd)/wfd*100",sep='')))  #% diff: riego
          
      #calculate across-model range of % changes
      ch = mat.or.vec((p-2),1)
      for (m in 1:(p-2))  {
        ch[m] = (mean.ylds[m] - mean.ylds[p-1] )/mean.ylds[p-1] *100
      }
      eval(parse(text=paste("yld.ag.",substr(treat[t],1,1),"[4:5,j] = range(ch,na.rm=T)",sep='')))
      
      #try bootstrapping across models to get CI
      boot = mat.or.vec(500,1)
      for (b in 1:500)  {boot.ind = sample(1:(p-2),(p-2),replace=T)
                         boot[b] = mean(mean.ylds[boot.ind])
                        }
      boot.ch = (boot - mean.ylds[p-1] )/mean.ylds[p-1]  * 100
      eval(parse(text=paste("yld.ag.",substr(treat[t],1,1),"[6:7,j] = quantile(boot.ch,c(.025,.975),na.rm=T)",sep='')))
      eval(parse(text=paste("yld.ag.",substr(treat[t],1,1),"[8,j] = sum(crop_",treat[t],"[ind.reg,'",treat[t],".area'])",sep='')))
      
    }
  }
}  
  
#label results and save
rownames(yld.ag.r) = c('WFD','MMM','%Ch','Range.ch.l','Range.ch.u','CI.l','CI.u','Area')
rownames(yld.ag.s) = rownames(yld.ag.r)
colnames(yld.ag.r) = c(regions,'LatAm')
colnames(yld.ag.s) = colnames(yld.ag.r)

if (subset==F)  {  
  eval(parse(text=paste(cultivos[c],".ch.r = yld.ag.r ",sep='')))
  eval(parse(text=paste(cultivos[c],".ch.s = yld.ag.s ",sep='')))
  eval(parse(text=paste("save(",cultivos[c],".ch.r,file='",path.res,"summaries/",cultivos[c],"_",material,".ch.r.Rdat')",sep="")))
  eval(parse(text=paste("save(",cultivos[c],".ch.s,file='",path.res,"summaries/",cultivos[c],"_",material,".ch.s.Rdat')",sep="")))
}

#try plotting boxplots with interannual variability by model
# have to aggregate to LAM or regions first
#look at physical area from SPAM to weight yield changes
#Calculate weighted averages by model & compare to WFD
boxplot.r = array(NA,dim=c(p-1,28,6))  #initialize matrices
boxplot.s = array(NA,dim=c(p-1,28,6))

#loop by region
for (r in 1:6)  {
  for (t in 1:2)  {  #then by treatment
    if (r<=5) {eval(parse(text=paste("ind.reg = which(crop_",treat[t],"$Region==regions[r] & zeros.wfd.",substr(treat[t],1,1),"<=14)",sep='')))
    }   else{
      eval(parse(text=paste("ind.reg = which(zeros.wfd.",substr(treat[t],1,1),"<=14)",sep='')))          
    }
    if (length(ind.reg)>1)  {
      for (j in 1:(p-1))  {   #loop through models
        for (y in c(1:5,7:28))  { #loop through years
          eval(parse(text=paste("boxplot.",substr(treat[t],1,1),"[j,y,r] = sum(yld_",treat[t],"[ind.reg,y,j]*area.",treat[t],"[ind.reg,y])/sum(area.",treat[t],"[ind.reg,y])",sep='')))    
        }
      }
    }
  }
}

dimnames(boxplot.r)[1] = list(models$Models[1:(p-1)])
dimnames(boxplot.r)[3] = list(c(regions,'LatAm'))
dimnames(boxplot.s)[1] = list(models$Models[1:(p-1)])
dimnames(boxplot.s)[3] = list(c(regions,'LatAm'))

par(ask=F)
if (cultivos[c]=='maiz') {ylim.c = c(0,9500)}  #hard-code ranges of plots
if (cultivos[c]=='arroz') {ylim.c = c(0,4500)}
if (cultivos[c]=='soya') {ylim.c = c(0,1100)}

boxplot(t(boxplot.r[c(11,1:10),,6]),xaxt='n',ylim=ylim.c)
text(x=seq(1,p,1.1),y=50,cex=1,labels = dimnames(boxplot.r)[[1]][c(11,1:10)], xpd=TRUE, srt=40, pos=2)
title(paste('Inter-annual variability for region: ',cultivos[c],' (riego)',sep=''))

boxplot(t(boxplot.s[c(11,1:10),,6]),xaxt='n',ylim=ylim.c)
text(x=seq(1,p,1.1),y=50,cex=1,labels = dimnames(boxplot.s)[[1]][c(11,1:10)], xpd=TRUE, srt=40, pos=2)
title(paste('Inter-annual variability for region: ',cultivos[c],' (secano)',sep=''))

#Calculate inter-annual variability (standard dev) for regions
yld.CV.r = array(NA,dim=c(6,6))  #initialize matrices
yld.CV.s = array(NA,dim=c(6,6))

for (r in 1:6)  {
  
  for (t in 1:2)  {
    eval(parse(text=paste("test = sum(is.na(boxplot.",substr(treat[t],1,1),"[,1,r]))",sep='')))
    if (test==0)  {  #check for NA's in 1st year
      
      eval(parse(text=paste("yld.cv = apply(boxplot.",substr(treat[t],1,1),"[,,r],1,function(x) sd(x,na.rm=T)/mean(x,na.rm=T))*100",sep='')))
      
      eval(parse(text=paste("yld.CV.",substr(treat[t],1,1),"[1,r] = yld.cv[(p-1)]",sep='')))  #WFD
      eval(parse(text=paste("yld.CV.",substr(treat[t],1,1),"[2,r] = mean(yld.cv[1:(p-2)])",sep='')))  #Multi-model mean
      
      eval(parse(text=paste("yld.CV.",substr(treat[t],1,1),"[3:4,r] = range(yld.cv[1:(p-2)])",sep='')))  #range of models
      
      boot = mat.or.vec(500,1)  #bootstrap results
      for (j in 1:500)  {boot.ind = sample(1:(p-2),(p-2),replace=T)
                         boot[j] = mean(yld.cv[boot.ind])}
      eval(parse(text=paste("yld.CV.",substr(treat[t],1,1),"[5:6,r] = quantile(boot,c(.025,.975))",sep='')))
    }
  }
}

dimnames(yld.CV.r)[1] = list(c('WFD','MMM','Range.ch.l','Range.ch.u','CI.l','CI.u'))
dimnames(yld.CV.r)[2] = list(c(regions,'LatAm'))
dimnames(yld.CV.s)[1] = list(c('WFD','MMM','Range.ch.l','Range.ch.u','CI.l','CI.u'))
dimnames(yld.CV.s)[2] = list(c(regions,'LatAm'))

#put results in data frame and save
if (subset==F)  {
  eval(parse(text=paste(cultivos[c],".cv.r = yld.CV.r ",sep='')))
  eval(parse(text=paste(cultivos[c],".cv.s = yld.CV.s ",sep='')))
  eval(parse(text=paste("save(",cultivos[c],".cv.r,file='",path.res,"summaries/",cultivos[c],"_",material,".cv.r.Rdat')",sep="")))
  eval(parse(text=paste("save(",cultivos[c],".cv.s,file='",path.res,"summaries/",cultivos[c],"_",material,".cv.s.Rdat')",sep="")))
}