suppressPackageStartupMessages(library("optparse"))

option_list <- list(
    make_option("--sqlite_database", help=''),
    make_option("--model_to_query", help='', default = NULL),
    make_option("--value_column", help='', default= 'predicted_expression'),
    make_option("--command", help='', default = NULL),
    make_option("--output_file_basename", help='')
)

opt <- parse_args(OptionParser(option_list=option_list))

library(RSQLite)
library(tidyverse)
library(abind)
library(glue)

input_rsqlite_db <- opt$sqlite_database #'/scratch/beagle3/temi/predictions_db/ctPred-predicted-expression-in-1000G.sqlite'

mydb <- dbConnect(RSQLite::SQLite(), input_rsqlite_db)
if(is.null(opt$model_to_query)){
    predictions <- dbGetQuery(mydb, glue::glue("SELECT * FROM {opt$value_column}"))
} else {
    predictions <- dbGetQuery(mydb, glue::glue("SELECT * FROM {opt$value_column} WHERE model = {opt$model_to_query}"))
}
dbDisconnect(mydb)

head(predictions)
dim(predictions)

predictions_split <- predictions %>% base::split(f = .$context) %>% purrr::map(., function(x){
    dplyr::select(x, any_of(c(individual, ensembl_id, ensembl_gene_id, opt$value_column))) %>% 
    tidyr::pivot_wider(id_cols = individual, names_from = any_of(c(ensembl_id, ensembl_gene_id)), values_from = opt$value_column) %>%
    tibble::column_to_rownames('individual') %>% 
    as.matrix()
}, .progress = TRUE)

length(predictions_split)

# match the rownames and columns
common_rownames <- lapply(predictions_split, rownames) %>% purrr::reduce(., intersect)
common_colnames <- lapply(predictions_split, colnames) %>% purrr::reduce(., intersect)

length(common_rownames); length(common_colnames)
# select what is common 
predictions_split.selected <- purrr::map(predictions_split, function(x){
    return(x[common_rownames, common_colnames, drop = F])
}, .progress = TRUE)

# bind using abind
outmat <- abind::abind(predictions_split.selected, along = 3)
dim(outmat)
print("INFO - output matrix is {dim(outmat)[1]} individual X {dim(outmat)[2]} gene X {dim(outmat)[3]} context")
# write out
saveRDS(outmat, file = glue::glue("{opt$output_file_basename}.rds.gz"), compress = TRUE)