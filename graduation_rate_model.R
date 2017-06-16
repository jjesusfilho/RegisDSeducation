############################Preprocessing############################
linReg=T
h2o=T
knn.impute=F #Did not work well
rf=F
##combine all data into single data set
year.tmp=2001
year.tmp.2=02

final.frame=data.frame()
for (i in 1:7){
  base.path="C:/Users/Will/Downloads/CollegeScorecard_Raw_Data/CollegeScorecard_Raw_Data/MERGED"
  
  if (year.tmp.2<10){
    year.tmp.2.1=as.character(paste("0",year.tmp.2,sep=""))
  } else
  { year.tmp.2.1=as.character(year.tmp.2)}
  
  path=paste(base.path,year.tmp,"_",year.tmp.2.1,"_PP.csv",sep="")
  tmp.frame=read.csv(path,stringsAsFactors=FALSE,na.strings=c("NULL","PrivacySuppressed"))
  tmp.frame$year=year.tmp
  
  tmp.frame=tmp.frame[,c('INSTNM'
                         ,'ADM_RATE'
                         ,'ACTCMMID'
                         ,'UGDS'
                         ,'TUITIONFEE_IN'
                         ,'TUITFTE'
                         ,'INEXPFTE'
                         ,'AVGFACSAL'
                         ,'PFTFAC'
                         ,'PFTFTUG1_EF'
                         ,'AGE_ENTRY'
                         ,'C150_4'
  )]
  
  final.frame=rbind(final.frame,tmp.frame)
  
  
  year.tmp=year.tmp+1
  if (year.tmp.2==99){
    year.tmp.2=0
  } else
    {year.tmp.2=year.tmp.2+1}
  gc()
}
colnames(final.frame)=colnames(tmp.frame)
write.csv(final.frame,"C:/Users/Will/Downloads/CollegeScorecard_Raw_Data/CollegeScorecard_Raw_Data/O8_14.csv",row.names = F)
gc()

#final.frame=na.omit(final.frame)

summary(final.frame)

#Feature selection for graduation rates
library(caret)
library(h2o)
library(class)
###remove redundent features
#remove two year institutions




#first attempt at fitting a regression
if (linReg==T){

library(corrplot)
final.frame.lm=na.omit(final.frame)  
final.frame.lm=final.frame.lm[final.frame.lm$C150_4>0,]
inst_names=(final.frame.lm$INSTNM)
yvals=final.frame.lm$C150_4
final.frame.lm=subset(final.frame.lm,select=-c(C150_4,INSTNM))
correlationMat=cor(final.frame.lm)
corrplot(correlationMat, method = "circle")  
final.frame.lm$yvals=yvals

lm1=lm(yvals~.,data=final.frame.lm)
fit.values=predict(lm1,final.frame.lm)
summary(lm1)
plot(final.frame.lm$yvals,fit.values,xlab = "Actual",ylab = "Predicted")
abline(coef=c(0,1))

final.frame.fitted=final.frame.lm
final.frame.fitted$fitted=lm1$fit.values
final.frame.fitted$names=inst_names

lm.sq.error=(final.frame.lm$yvals-fit.values)^2
lm.rmse=sqrt(sum(lm.sq.error)/length(lm.sq.error))
lm.rmse

#plots
plot(final.frame.lm$ACTCMMID,final.frame.lm$yvals)
}
##########clustering to impute values from the missing set

if (knn.impute==T){
library(DMwR)
knn.frame<- final.frame[!(is.na(final.frame$C150_4)==T),]
summary(knn.frame)
new.data=knn.frame[,2:ncol(knn.frame)]
new.data=  knnImputation(new.data,meth="median")
summary(new.data)

lm.knn=lm(C150_4~.,data=new.data)
summary(lm.knn)
knn.fit.values=predict(lm.knn,new.data)
plot(knn.fit.values,knn.frame$C150_4)
abline(coef=c(0,1))
}


#h2o attempt
if (h2o==T){
  #hyperparameterization loop
  h2o.init()
h2o_train=as.h2o(final.frame.lm)
h20_model=h2o.deeplearning(y=11,training_frame = h2o_train,hidden = c(200,200)) #previously 200
predictions=predict(h20_model,h2o_train)
predictions2=as.vector(predictions)
predictions2=ifelse(predictions2>1,1,predictions2)
predictions2=ifelse(predictions2<0,0,predictions2)

plot(final.frame.lm$yvals,predictions2,xlab = "Actual",ylab = "Predicted")
abline(coef=c(0,1))

deep.error.sq=(final.frame.lm$yvals-predictions2)^2
deep.error=(final.frame.lm$yvals-predictions2)/(predictions2)
rsme.deep=sqrt(sum(deep.error.sq)/length(deep.error.sq))


final.frame.fitted$deep=as.vector(predictions2)

}





#Model evaluation Analysis
large_misses=final.frame.fitted[deep.error.sq>.5,]
write.csv(large_misses,"C:/Users/Will/Documents/Regis/MSDS692/large_miss.csv",row.names = F)
underage=final.frame.fitted[final.frame.fitted$AGE_ENTRY<18,]
high_accuracy=final.frame.fitted[abs(deep.error)<.01,]
accuracy99=nrow(high_accuracy)/nrow(final.frame.fitted) 
accuracy95=nrow(final.frame.fitted[abs(deep.error)<.05,])/nrow(final.frame.fitted)
accuracy90=nrow(final.frame.fitted[abs(deep.error)<.1,])/nrow(final.frame.fitted)

High_predictions=nrow(final.frame.fitted[final.frame.fitted$deep>final.frame.fitted$yvals,])/nrow(final.frame.fitted)
low_admit=final.frame.fitted[final.frame.fitted$ADM_RATE<.15,] #low admission rates lead to very accurate predictions
