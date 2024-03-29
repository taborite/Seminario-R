rm(list = ls())
graphics.off()

pacman::p_load(caret,GGally,magrittr,pacman,
               parallel,randomForest,rattle,
               rio,tictoc,tidyverse,ggfortify,pROC)

#see https://cran.r-project.org/web/packages/caret/vignettes/caret.html

#setwd('data/seminario R/')
data = readxl::read_excel('data/osl_parnaiba_table.xlsx', sheet = 'by_aliquot') %>%
  print()

data$BOSLF <- as.numeric(data$BOSLF)
data$BOSLM <- as.numeric(data$BOSLM)
data$BOSLS <- as.numeric(data$BOSLS)

colnames(data)[9] <- 'IRSL'

data$BOSLF[is.na(data$BOSLF)] <- 33.333
data$BOSLM[is.na(data$BOSLM)] <- 33.333
data$BOSLS[is.na(data$BOSLS)] <- 33.333

osl.c <- 1:length(data$BOSL1s)
for (i in 1:length(data$BOSL1s)) {
  if (data$BOSL1s[i]>9) {
    osl.c[i] <- 'High'
  } else if (data$BOSL1s[i]<4) {
    osl.c[i] <- 'Low'
  } else {
    osl.c[i] <- 'Medium'}
}

data %<>%
  #mutate(osl.t = ifelse(osl>=9,'High','Medium'), osl.t = as_factor(osl.t)) %>%
  mutate(osl.c = as.factor(osl.c)) %>%
  print()

# Random forest of decision trees on training data ####
#set.seed(123)
train <- data %>% slice_sample(n=216) %>% as.data.frame()
test <- anti_join(data, train) %>% as.data.frame()

control <- trainControl(method = 'repeatedcv', number = 10, repeats = 3, search = 'random',
                       allowParallel = T)

traindata <- train[,5:12]
trainclass <- train$unit2num
model <- train(Unit~BOSL1s+BOSLS+BOSLM+BOSLF+IRSL+TL110oC+TL110pos+TL325pos, 
               data=train,
               method = 'rf', trControl = control,
               metric = 'Accuracy', tuneLength = 15, ntree = 300,
               na.action = 'na.omit')

model
model %>% plot()
model$finalModel
model$finalModel %>% plot()

osl.t <- predict(model, train)
table(actualclass = train$Unit, predictedclass = osl.t) %>% 
  confusionMatrix()

#Random forest on test data
osl.p <- predict(model, test)
osl.p <- data.frame(osl.p)
table(actualclass = test$Unit, predictedclass = osl.p$osl.p) %>% 
  confusionMatrix()

# Summary of results ####
test %>% pull(osl.c) %>% summary()

#ROC
require(randomForest)
data <- as.data.frame(data)
data <- data[,-c(1,2,4,13,14)]
data$Unit <- factor(data$Unit)
model <- randomForest(Unit~., data=data)

test$unit2num[test$Unit=='Serra Grande'] <- 1
test$unit2num[test$Unit=='Pimenteiras'] <- 2
test$unit2num[test$Unit=='Cabecas'] <- 3
test$unit2num[test$Unit=='Longa'] <- 4
test$unit2num[test$Unit=='Poti'] <- 5
test$unit2num[test$Unit=='Piaui'] <- 6
test$unit2num[test$Unit=='Motuca'] <- 7
test$unit2num[test$Unit=='Sambaiba'] <- 8

osl.p$unit2num[osl.p$osl.p=='Serra Grande'] <- 1
osl.p$unit2num[osl.p$osl.p=='Pimenteiras'] <- 2
osl.p$unit2num[osl.p$osl.p=='Cabecas'] <- 3
osl.p$unit2num[osl.p$osl.p=='Longa'] <- 4
osl.p$unit2num[osl.p$osl.p=='Poti'] <- 5
osl.p$unit2num[osl.p$osl.p=='Piaui'] <- 6
osl.p$unit2num[osl.p$osl.p=='Motuca'] <- 7
osl.p$unit2num[osl.p$osl.p=='Sambaiba'] <- 8

data$unit2num[data$Unit=='Serra Grande'] <- 1
data$unit2num[data$Unit=='Pimenteiras'] <- 2
data$unit2num[data$Unit=='Cabecas'] <- 3
data$unit2num[data$Unit=='Longa'] <- 4
data$unit2num[data$Unit=='Poti'] <- 5
data$unit2num[data$Unit=='Piaui'] <- 6
data$unit2num[data$Unit=='Motuca'] <- 7
data$unit2num[data$Unit=='Sambaiba'] <- 8

res.rf <- data.frame(model$predicted)
res.rf$mod2num[res.rf$model.predicted=='Serra Grande'] <- 1
res.rf$mod2num[res.rf$model.predicted=='Pimenteiras'] <- 2
res.rf$mod2num[res.rf$model.predicted=='Cabecas'] <- 3
res.rf$mod2num[res.rf$model.predicted=='Longa'] <- 4
res.rf$mod2num[res.rf$model.predicted=='Poti'] <- 5
res.rf$mod2num[res.rf$model.predicted=='Piaui'] <- 6
res.rf$mod2num[res.rf$model.predicted=='Motuca'] <- 7
res.rf$mod2num[res.rf$model.predicted=='Sambaiba'] <- 8

roc <- roc(data$Unit, res.rf$mod2num)
auc(roc)
plot(roc, main='Receiver Operating Characteristic curve')

