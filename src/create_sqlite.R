


library(tidyverse)
library(glue)
library(data.table)
library(DBI)
library(RSQLite)

# I have a directory within this called gtex for adult GTEx data
project_directory <- '/beagle3/haky/users/temi/projects/dgtex'
data_directory <- "/beagle3/haky/users/temi/data/lctpred-dGTEx-in-aGTEx-genotypes"
agtex_tissues <- list.files(data_directory, pattern = "_predict.txt") %>% gsub("_predict.txt", "", .)

lctpred_agtex <- purrr::map(agtex_tissues, function(tissue){
    fileY <- glue::glue("{data_directory}/{tissue}_predict.txt")
    if(file.exists(fileY)){
        matrixY <- data.table::fread(fileY) %>%
            dplyr::select(-FID) 
        new_names <- colnames(matrixY) %>% strsplit('\\.') %>% sapply(getElement, 1)
        matrixY <- matrixY %>% 
            data.table::setnames(old = colnames(.), new = new_names) %>% 
            tibble::column_to_rownames('IID') %>% 
            as.matrix()

        return(matrixY)
    }
}, .progress = TRUE)

names(lctpred_agtex) <- agtex_tissues

lctpred_agtex[[1]][1:5, 1:5]

widetolong <- purrr::map(names(lctpred_agtex), function(nx){
    mat <- lctpred_agtex[[nx]]
    # rename the columns
    nn <- gsub(paste0(nx, '_'), '', colnames(mat))
    colnames(mat) <- nn
    as.data.table(mat, keep.rownames = 'individual') %>% 
        tidyr::pivot_longer(cols = !c(individual), names_to = 'tss', values_to = 'predicted_expression') %>%
        dplyr::mutate(context = nx)
}, .progress = TRUE)

widetolong.dt <- dplyr::bind_rows(widetolong)

dim(widetolong.dt); widetolong.dt[1:5, ]

# map the genes
gene_mappings <- data.table::fread('/beagle3/haky/users/temi/projects/dgtex/files/canonical_tss.matched_genes.tsv') %>% dplyr::select(locus, ensembl_gene_id) 
# REMOVE DUPLICATES

# remove duplicates
undupgenes <- gene_mappings %>%
  group_by(locus) %>%
  summarize(nn = n()) %>%
  filter(nn == 1)

gmappings <- gene_mappings %>% dplyr::filter(locus %in% undupgenes$locus)

# common genes
common_locus <- intersect(unique(widetolong.dt$tss), gmappings$locus)
length(common_locus)

gmappings <- gmappings %>% dplyr::filter(locus %in% common_locus)

data.predictions <- widetolong.dt %>% dplyr::inner_join(gmappings, by = c('tss' = 'locus')) %>% dplyr::select(individual, context, ensembl_gene_id, predicted_expression)


head(data.predictions)
dim(data.predictions)

mappings <- data.table::fread('/beagle3/haky/users/temi/projects/dgtex/files/dgtex_agtex_tissues.mappings.tsv')

context_mappings <- mappings %>% dplyr::select(tissue = superTissue, dgtexContext) %>% distinct()

print('INFO - Saving to sqlite')

pdb <- "/scratch/beagle3/temi/predictions_db/lctPred-dGTEx-predicted-expression-in-aGTEx.sqlite"

mydb <- dbConnect(RSQLite::SQLite(), pdb)

dbWriteTable(mydb, "predicted_expression", data.predictions)
dbWriteTable(mydb, "context_metadata", context_mappings)

dbDisconnect(mydb)