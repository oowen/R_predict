# prog.r
require(readr)
setwd("/home/osboxes/R")
out <- read_csv("kc_house_data.csv")
# str(out)

any(is.na(out)) # output FALSE
#
str(out)

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