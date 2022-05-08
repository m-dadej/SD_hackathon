library(tidyverse)
library(ggplot2)

df_raw <- read.csv("data/raw/train.csv")

set.seed(1)

# df_raw <- sample_frac(df_raw, size = 0.1) # prototyping with better performance

# encoding function
dummy_encode <- function(df, var){
  mutate(df, dummy_value = 1) %>%
  pivot_wider(names_from = var, 
              values_from = dummy_value,
              values_fill = 0, names_prefix = paste0(str_replace(var, " ", "_"), "_"))
}

# cleaning func:
clean_rate <- function(x){
  ifelse(x == "", NA, as.numeric(str_remove_all(x, "%"))/100)
}

# actual preproc of data ------------


df <- dummy_encode(df_raw, "property_type") %>%
    dummy_encode("room_type") %>%
    dummy_encode("bed_type") %>%
    mutate(amenity_tv = ifelse(grepl("TV", amenities),1,0), # Assumption: no difference between cable or not
           amenity_net = ifelse(grepl("Internet", amenities),1,0), # Assumption: every net is wireless
           amenity_air = ifelse(grepl("Air conditioning", amenities),1,0),
           amenity_kitchen = ifelse(grepl("Kitchen", amenities), 1,0),
           amenity_friendly = ifelse(grepl("friendly", amenities),1,0), # assumption: any friendly is the same
           amenity_smoke = ifelse(grepl("Smoke detector", amenities),1,0),
           amenity_heating = ifelse(grepl("Heating", amenities),1,0),
           amenity_parking = ifelse(grepl("Free parking on premises", amenities), 1, 0),
           amenity_washr = ifelse(grepl("Washer", amenities),1,0),
           cleaning_fee = ifelse(cleaning_fee == "True", 1, 0),
           first_review = as.Date(first_review),
           host_has_profile_pic = ifelse(host_has_profile_pic == "t", 1, 0),
           host_identity_verified = ifelse(host_identity_verified == "t", 1, 0),
           host_response_rate = clean_rate(host_response_rate),
           host_since = as.Date(host_since),
           desc_length = nchar(description),
           instant_bookable = ifelse(instant_bookable == "t", 1, 0),
           last_review = as.Date(last_review)) %>%
           select(-c(id, thumbnail_url, name, description)) %>%  # maybe will be useful later 
           select_if(function(x){sum(x != 0, na.rm = TRUE) > 30}) # drop variables that are rare
                     
colnames(df) <- colnames(df) %>%
                tolower() %>%
                str_remove_all("/|& |-")%>%
                str_replace(" ", "_")

rm(df_raw, clean_rate)
