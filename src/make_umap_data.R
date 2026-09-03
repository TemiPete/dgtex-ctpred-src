# Author: Temi
# Date: Tues Sep 16 2025
# Description: Correlate ctPred predictions with GTEx
# Usage: Rscript train_enet.R [options]

suppressPackageStartupMessages(library("optparse")) |> suppressPackageStartupMessages()

option_list <- list(
    make_option("--matrixX", default = NULL, help='A 3D array, preferrably in rds format'),
    make_option("--matrixY", default = NULL, help='A 3D array, preferrably in rds format'),
    make_option("--input_data", default = NULL, help='An input dataframe to the UMAP'),
    make_option("--output_file_basename", type="character", help='How many cv folds?'),
    make_option("--top_n_most_variable", type="numeric", default = NULL, help='How many cv folds?')
)

opt <- parse_args(OptionParser(option_list=option_list))

library(glue) |> suppressPackageStartupMessages()
library(R.utils) |> suppressPackageStartupMessages()
library(data.table) |> suppressPackageStartupMessages()
library(tidyverse) |> suppressPackageStartupMessages()
library(umap) |> suppressPackageStartupMessages()


# project_directory <- '/beagle3/haky/users/temi/projects/dgtex'

# mX <- file.path(project_directory, "gtex/processed_predictions/ctPred-aGTEx-in-1000G.predicted_expression.rds.gz") %>% readRDS()
# mY <- file.path(project_directory, "data/predictions/ctPred-dGTEx-in-1000G.predicted_expression.rds.gz") %>% readRDS()



if(!is.null(opt$input_data) & file.exists(opt$input_data)){
    mat_mxmy <- data.table::fread(opt$input_data)
} else if(!is.null(opt$matrixX) & !is.null(opt$matrixY)) {
    mX <- file.path(opt$matrixX) %>% readRDS()
    mY <- file.path(opt$matrixY) %>% readRDS()
    dd_agtex <- as.data.frame.table(mX) %>%
        dplyr::mutate(dataset = 'aGTEx') %>%
        dplyr::mutate(id = paste0(Var3, '-', Var2)) %>%
        dplyr::select(id, gene = Var1, prediction = Freq, dataset) %>%
        tidyr::pivot_wider(id_cols = c(id, dataset), names_from = gene, values_from = prediction) %>%
        tibble::column_to_rownames('id') 

    dd_dgtex <- as.data.frame.table(mY) %>%
        dplyr::mutate(dataset = 'dGTEx') %>%
        dplyr::mutate(id = paste0(Var3, '-', Var2)) %>%
        dplyr::select(id, gene = Var1, prediction = Freq, dataset) %>%
        tidyr::pivot_wider(id_cols = c(id, dataset), names_from = gene, values_from = prediction) %>%
        tibble::column_to_rownames('id')
    mat_mxmy <- rbind(dd_agtex, dd_dgtex)
    data.table::fwrite(mat_mxmy, glue::glue("{opt$output_file_basename}.umap_input_matrix.tsv.gz"), compress = 'gzip', row.names = T, col.names = T, quote = F, sep = '\t')
} else if (is.null(opt$matrixX) & is.null(opt$matrixY) & is.null(opt$input_data)){
    print("INFO - No input supplied")
    quit()
}

print(dim(mat_mxmy))

if(!is.null(opt$top_n_most_variable)){
    print(glue::glue("INFO - Using the top most {opt$top_n_most_variable} variable genes"))
    indata <- mat_mxmy %>% dplyr::select(-dataset) %>% tibble::column_to_rownames('V1') %>% as.matrix()
    varss <- apply(indata, 2, sd)^2
    topn_genes <- sort(varss, decreasing = TRUE)[1:opt$top_n_most_variable]
    ddmat <- indata[, names(topn_genes)]
    print(dim(ddmat))
} else {
    ddmat <- mat_mxmy[, !colnames(mat_mxmy) == 'dataset']
    print(dim(ddmat))
}

print("INFO - Running UMAP...")
dd_umap <- umap::umap(ddmat)
saveRDS(dd_umap, glue::glue("{opt$output_file_basename}.umap_object.tsv.gz"), compress = TRUE)

# Extract the embedding
umap_embedding <- as.data.frame(dd_umap$layout)
colnames(umap_embedding) <- c("UMAP1", "UMAP2")

# Add back the original categorical variable (e.g., species) for coloring
umap_embedding$dataset <- mat_mxmy$dataset

print("INFO - Finished, and saving UMAP embedding...")
data.table::fwrite(umap_embedding, glue::glue("{opt$output_file_basename}.umap_embedding.tsv.gz"), compress = 'gzip', row.names = T, col.names = T, quote = F, sep = '\t')