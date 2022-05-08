
source("data_preproc1.R")

set.seed(1)

# coordinates of city centers
city_centers <- data.frame(city = c("Boston", "Chicago", "DC", "LA", "NYC", "SF"),
                           center_y = c(42.36083, 41.8894, 38.905, 34.0423, 40.7657, 37.7929),
                           center_x = c(-71.05742, -87.6385, -77.0297,-118.2474,-73.9773,-122.3995))

# simple distance function
dist <- function(x_1, x_2, y_1, y_2){
  sqrt((x_2 - x_1)^2 + (y_2 - y_1)^2)
}

df_time <- max(df$last_review, na.rm = TRUE) # when was data published

popular_zip <- df$zipcode %>% 
                table() %>%
                as.data.frame() %>%
                arrange(desc(Freq)) %>%
                head(20) %>%
                .[,1]%>%
                as.character()

df <- left_join(df, city_centers, by = "city") %>%
      mutate(dist_from_cent = dist(longitude, center_x, latitude, center_y),
             cleaning_price = cleaning_fee * accommodates,
             host_exp = as.numeric(df_time - host_since),  
             no_guest_start = as.numeric(last_review - host_since),
             reviews_per_day = number_of_reviews / host_exp,
             reviews_per_day = ifelse(is.infinite(reviews_per_day), 0, reviews_per_day),
             no_guest_time = as.numeric(df_time - last_review),
             cancellation_policy = recode(cancellation_policy, 
                                          "flexible" = 0,
                                          "moderate" = 1,
                                          "strict" = 2,
                                          "super_strict_30" = 3,
                                          "super_strict_60" = 4),
             zipcode = ifelse(zipcode %in% popular_zip, zipcode, NA)) %>% # some popular zipcodes are encoded
       dummy_encode("zipcode")

df_modeling <- select(df, -c(amenities, city, first_review, host_since ,zipcode_NA,
                             last_review, neighbourhood, center_y, center_x))


rm(df_time, city_centers, dist, dummy_encode)
