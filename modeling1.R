library(caret)
library(mlr)
library(mlrCPO)
library(glmnet)
library(DALEX)
library(DALEXtra)

source("feature_eng1.R")

set.seed(1)

train_split <- 0.8

set.seed(1)
train_index <- sample(1:nrow(df_modeling), size = nrow(df_modeling)*train_split)
train_df <- df_modeling[train_index,]
test_df <- df_modeling[-train_index,]

# introducing n nearest neighbours
# be cautious: This chunk takes a lot of time to run. Thats why I precalculated it.

#train_df <- train_df %>%
#            mutate(n_neighbours = map2(.x = longitude, .y = latitude,
#                            .f = ~nrow(points_in_circle(rename(train_df, "lon" = longitude, "lat" = latitude),
#                                                        lon_center = .x, lat_center = .y, radius = 60)))) %>%
#            unnest(n_neighbours) %>%
#            ungroup()

#test_df <- test_df %>%
#            mutate(n_neighbours = map2(.x = longitude, .y = latitude,
#                            .f = ~nrow(points_in_circle(rename(train_df, "lon" = longitude, "lat" = latitude),
#                                                        lon_center = .x, lat_center = .y, radius = 60)))) %>%
#            unnest(n_neighbours) %>%
#            ungroup()

# note that I used train_df to calculate number of nearest houses for test_df instead of calculating it from test_df
# this would be a lookahead bias


# I precalculated the datasets so code is easier to reproduce:
test_df <- read.csv("data/test_df_near.csv") %>%
            select(-c(X))
train_df <- read.csv("data/train_df_near.csv") %>%
              select(-c(X))

non_na_features <- select_if(train_df, function(x){sum(is.na(x)) == 0}) %>%
                    select(-log_price) %>%
                    colnames()
                    
suppressWarnings({imp_train_df <- impute(as.data.frame(train_df), target = "log_price", 
                   cols = list(host_response_rate   = imputeLearner("regr.glm", features = non_na_features),
                               review_scores_rating = imputeLearner("regr.glm", features = non_na_features),
                               bedrooms = imputeLearner("regr.glm", features = non_na_features),
                               beds = imputeLearner("regr.glm", features = non_na_features),
                               bathrooms = imputeLearner("regr.glm", features = non_na_features),
                               reviews_per_day = imputeLearner("regr.glm", features = non_na_features),
                               host_exp = imputeLearner("regr.glm", features = non_na_features),
                               no_guest_start = imputeLearner("regr.glm", features = non_na_features),
                               no_guest_time = imputeLearner("regr.glm", features = non_na_features)))}) 

# Warning: prediction from a rank-deficient fit may be misleading
# I do not care as long as imputation is better than mean

train_task <- makeRegrTask(data = as.data.frame(imp_train_df$data), target = "log_price")

suppressWarnings({test_df_imp <- as.data.frame(reimpute(test_df, imp_train_df$desc))})
test_task  <- makeRegrTask(data =test_df_imp,
                           target = "log_price")

param_set <- makeParamSet(
  makeNumericParam("eta", lower = 0.1, upper = 0.8),
  makeIntegerParam("gamma", lower = 0, upper = 10),
  makeIntegerParam("min_child_weight", lower = 0, upper = 3),
  makeNumericParam("lambda", lower = 0, upper = 0.9),
  makeNumericParam("alpha", lower = 0, upper = 0.9),
  makeIntegerParam("nrounds", lower = 30, upper = 100)
)

start.time <- Sys.time()
ctrl  <-  makeTuneControlMBO()
rdesc <-  makeResampleDesc("CV", iters = 5)
res   <-  tuneParams("regr.xgboost", 
                     task = train_task, 
                     resampling = rdesc,
                     par.set = param_set, 
                     control = ctrl)

learner <- makeLearner(cl = "regr.xgboost", par.vals = res$x, 
                       predict.type = "response")
model   <- mlr::train(learner = learner, task = train_task)

end.time <- Sys.time()
time.taken <- end.time - start.time
time.taken
preds   <- predict(model, task = test_task)


# saveRDS(model, "models/model_xgb_n.rds")
# model <- readRDS("models/model1_xgb.rds")

# benchmark model - linear with regularization
bench_model <- glmnet(y = imp_train_df$data$log_price, 
                      x = select(imp_train_df$data, -log_price))

# par.vals = list(verbose = 1, nrounds = 50)


performance(preds, measures = list(expvar, rsq, mae, medae))
predict.glmnet(bench_model, newx = as.matrix(select(test_df_imp, -log_price))) %>%
  as.data.frame() %>%
  cbind(actual = test_df_imp$log_price) %>%
  pivot_longer(cols = -actual) %>%
  group_by(name) %>%
  summarise(mae = mean(abs(value - actual)),
            medae = median(abs(value - actual)),
            rsq = measureRSQ(actual, value)) %>%
  arrange(mae)

ggplot(as.data.frame(preds)) +
  geom_point(aes(x = truth, y = response))

# City where model generalizes the best is Boston and the worse is DC
as.data.frame(preds) %>%
  cbind(df[-train_index,]) %>%
  group_by(city) %>%
  summarise(mae = mean(abs(response - truth)),
            medae = median(abs(response - truth)))

geom_error_plot <- as.data.frame(preds) %>%
  cbind(df[-train_index,]) %>%
  ggplot(aes(y = latitude, x = longitude, color = abs(response-truth)), size = 0.1) +
  geom_point() +
  facet_wrap(~city, scales = "free")+
  scale_colour_viridis_c(option = "B") +
  labs(title = "Geographical distribution of model error")
ggsave("graphics/geo_error.png", width = 10, height = 9)

as.data.frame(preds) %>%
  cbind(df[-train_index,]) %>%
  ggplot(aes(x = dist_from_cent, y = log_price)) +
  geom_point()

explainer_obj <- explain_mlr(model, test_df_imp, test_df_imp$log_price, label = "xgb1", 
            verbose = TRUE, precalculate = FALSE)

model_performance(explainer_obj)

f_importance_plot <- plot(feature_importance(explainer_obj))
ggsave(plot = f_importance_plot, "graphics/f_importance.png", width = 7, height = 9)

model_diagnostics(explainer_obj) %>% plot()


pd <- generatePartialDependenceData(model, test_task, "dist_from_cent")

pd_dist <- plotPartialDependence(pd) +
  labs(title = "Partial dependence of distance from center to house") +
  theme_minimal()

ggsave("graphics/pd_dist.png",pd_dist, height = 5, width = 7)

pd_reviews <- generatePartialDependenceData(model, test_task, "reviews_per_day")

plot_rev <- plotPartialDependence(pd_reviews) +
  labs(title = "Partial dependence of Average daily number of reviews on log price") +
  theme_minimal()

ggsave("graphics/pd_rev.png",plot_rev, height = 5, width = 7)

