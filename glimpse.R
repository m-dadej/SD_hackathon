library(tidyverse)
library(ggplot2)
library(vroom)
library(geosphere)


df_raw <- read.csv("data/raw/train2.csv")

glimpse(df_raw)

apply(df_raw, 2, function(x){sum(is.na(x))}) # small n of NAs

df_raw$zipcode %>% 
  table() %>%
  as.data.frame() %>%
  arrange(desc(Freq)) %>%
  head(20)

# overview of what to preproc and how-------------

apply(df_raw, 2, function(x){length(unique(x))}) 
# varaibles for dummy-encoding:  property_type, room_type, bed_type, city 

# frequency of available amenities:
do.call(paste, c(as.list(df_raw$amenities), sep = "")) %>%
  str_replace_all( "[[:punct:]]", ",") %>%
  str_split("[[:punct:]]") %>%
  .[[1]] %>%
  table() %>%
  as.data.frame() %>%
  arrange(desc(Freq))

# less than 100 is not worth to include
# Worth to take top 5-7 and discard the rest


df_raw$cancellation_policy %>% table() # this can be orderered categorical data

df_raw$accommodates %>% table()
# cleaning fee is 0-1
# first review as date
# host characteristics to 0-1
# host response rate to numeric
# host since to date
# instant_bookable to 0-1
# last_review as date


# EDA -----------


# longitude latitude

ggplot(df_raw) +
  geom_point(aes(x = longitude, y = latitude)) +
  facet_wrap(~city, scales = "free")

# feature eng. ideas:

# 1. concentration - more objects nearby, lower price due to the competition. 
# 2. distance from center - obvious one but important to control for city!
# 3. interaction with cleaning_fee and size of house

# name - I can look for some words but not sure if it's worth to spend a lot of time
# neighbourhood - Same as above. Maybe "Hills" or "Bay" in name suggest more prestige?
# thumbnail_url - would love to make some image classification but aint nobody got time for that.
#     other than that: NA -> host dont want to show house -> the house looks bad 
# zipoce - we can only get stat and county, which is useless info given we have the long lat data
#


ggplot(df_raw) +
  geom_density(aes(x = exp(log_price)))

group_by(df, last_review) %>%
  summarise(price = median(log_price)) %>%
  ungroup() %>%
  ggplot(aes(x = last_review, y = price)) +
  geom_line()

rename(df, "lon" = longitude, "lat" = latitude) %>%
  select(lon, lat) %>%
  mutate(n_nearby = map2(.$lon, .$lat, ~points_in_circle(., .x, .y, lon = lon, radius = 1000)))

rename(df, "lon" = longitude, "lat" = latitude) %>%
spatialrisk::points_in_circle()



points_in_circle(Groningen, lon_center = 6.571561, lat_center = 53.21326, radius = 60)




start.time <- Sys.time()

sample_n(df, 37000) %>%
  select(longitude, latitude, city) %>%
  rename("lon" = longitude, "lat" = latitude) %>%
  mutate(n = map2(.x = lon, .y = lat,
                  .f = ~nrow(points_in_circle(rename(df, "lon" = longitude, "lat" = latitude),
                                              lon_center = .x, lat_center = .y, radius = 60)))) %>%
  unnest(n) %>%
  ungroup()

end.time <- Sys.time()
time.taken <- end.time - start.time
time.taken

table(df$city)

full_join(nearest_base, select(nearest_cities, -city), by = c("longitude", "latitude")) %>%
  as.data.frame()

nearest_cities$n %>% is.na() %>% sum()

as.data.frame(nearest_base)
as.data.frame(select(nearest_cities, -city))

select(df, longitude, latitude) %>%
  as.matrix() %>%
  cbind(X=rowSums(distm(df[,c("longitude", "latitude")], 
                         fun = distHaversine) / 1000 <= 10000))
  
  
  mutate(n_neighbours = rowSums(distm(as.matrix(select(df, longitude, latitude)), distHaversine) / 1000 <= 10000))

set.seed(1)
radius<-10
lat<-runif(10,-90,90)
long<-runif(10,-180,180)
id<-1:10
dat<-cbind(id,lat,long)


cbind(dat, X=rowSums(distm (dat[,3:2], 
                            fun = distHaversine) / 1000 <= 10000))
