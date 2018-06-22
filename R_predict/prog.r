# prog.r

# SET WORKSPACE -----------------------------
require(readr)
setwd("/home/osboxes/R/R_predict")
out <- read_csv("kc_house_data.csv")

# CHECK DATA ------------------------------
any(is.na(out)) # output FALSE
str(out)
# STEPWISE ---------------------------------------------------------------
#rul_zscore = scale(rul)
set.seed(18)
train.index <- sample(x = 1:nrow(out),size=ceiling(0.8*nrow(out)))

train = out[train.index,]
test = out[-train.index,]

null = lm(price ~ 1,data = train)
full = lm(price ~ .,data = train)

forward.lm = step(null,
                  scope = list(lower=null,upper=full),
                  direction = "forward")

summary(forward.lm)
# create a dataframe of the output feature from stepwise  
feature <- data.frame(  out$sqft_living,
                        out$lat,
                        out$grade,
                        out$yr_built,
                        out$bedrooms,
                        out$bathrooms,
                        out$long,
                        out$zipcode,
                        out$sqft_living15,
                        out$condition,
                        out$floors,
                        out$price)
colnames(feature) = c(  "sqft_living",
                        "lat",
                        "grade",
                        "yr_built",
                        "bedrooms",
                        "bathrooms",
                        "long",
                        "zipcode",
                        "sqft_living15",
                        "condition",
                        "floors",
                        "price")
#str(feature)

# gbm predict
require(xgboost)
set.seed(3)
train.index <- sample(x=1:nrow(feature), size=ceiling(0.8*nrow(feature) ))

train = feature[train.index, ]
test = feature[-train.index, ]

dtrain = xgb.DMatrix(data = as.matrix(train[,1:8]),label = train$price)
dtest = xgb.DMatrix(data = as.matrix(test[,1:8]),label = test$price)
xgb.params = list(
  #col的抽樣比例，越高表示每棵樹使用的col越多，會增加每棵小樹的複雜度
  colsample_bytree = 0.5,   #0.5->0.8                 
  # row的抽樣比例，越高表示每棵樹使用的col越多，會增加每棵小樹的複雜度
  subsample = 0.5, #0.5->0.8                      
  booster = "gbtree",
  # 樹的最大深度，越高表示模型可以長得越深，模型複雜度越高
  max_depth = 2,        #2->3   
  # boosting會增加被分錯的資料權重，而此參數是讓權重不會增加的那麼快，因此越大會讓模型愈保守
  eta = 0.03, 
  # 或用'mae'也可以
  eval_metric = "rmse",                      
  objective = "reg:linear",
  # 越大，模型會越保守，相對的模型複雜度比較低
  gamma = 0) #0->-1     

cv.model = xgb.cv(
  params = xgb.params, 
  data = dtrain,
  nfold = 5,     # 5-fold cv
  nrounds=200,   # 測試1-100，各個樹總數下的模型
  # 如果當nrounds < 30 時，就已經有overfitting情況發生，那表示不用繼續tune下去了，可以提早停止                
  early_stopping_rounds = 30, 
  print_every_n = 20 # 每20個單位才顯示一次結果，
) 
tmp = cv.model$evaluation_log

plot(x=1:nrow(tmp), y= tmp$train_rmse_mean, col='red', xlab="nround", ylab="rmse", main="Avg.Performance in CV") 
points(x=1:nrow(tmp), y= tmp$test_rmse_mean, col='blue') 
legend("topright", pch=1, col = c("red", "blue"), 
       legend = c("Train", "Validation") )

best.nrounds = cv.model$best_iteration 
best.nrounds

xgb.model = xgb.train(paras = xgb.params, 
                      data = dtrain,
                      nrounds = best.nrounds) 
xgb_y = predict(xgb.model, dtest)

library(ggplot2)
x = c(1:100) 
y1 = test$price[1:100]
y2 = xgb_y[1:100]
df1 <- data.frame(x,y1,y2)
df1c = df1[order(df1$y1),]
#
#ggplot(df1,aes(x=c(1:100),y = y1))+
#  geom_line() +
#  geom_line(aes(x=c(1:100),y = y2)) 

library(lattice)

xyplot(y1 + y2 ~ x, df1, type = "p")