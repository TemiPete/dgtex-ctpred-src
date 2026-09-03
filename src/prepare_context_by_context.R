# Author: Temi
# Date: Tues Sep 16 2025
# Description: Correlate ctPred predictions with GTEx
# Usage: Rscript train_enet.R [options]

# suppressPackageStartupMessages(library("optparse")) |> suppressPackageStartupMessages()

# option_list <- list(
#     make_option("--matrixX", help='A 3D array, preferrably in rds format'),
#     make_option("--matrixY", help='A 3D array, preferrably in rds format'),
#     make_option("--output_file_basename", type="character", help='How many cv folds?')
# )

# opt <- parse_args(OptionParser(option_list=option_list))

library(glue) |> suppressPackageStartupMessages()
library(R.utils) |> suppressPackageStartupMessages()
library(data.table) |> suppressPackageStartupMessages()
library(tidyverse) |> suppressPackageStartupMessages()
library(abind) |> suppressPackageStartupMessages()

# dt_comparisons <- data.table::fread(opt$comparison_file)
gene_correlations <- data.table::fread("/beagle3/haky/users/temi/projects/dgtex/data/correlations/aGTEx-vs-dGTEx.predicted.genes.correlation.tsv.gz")

gene_correlations.separated <- gene_correlations %>%
        tidyr::separate_wider_delim(cols = comparison, delim = ':', names = c('context1', 'context2'))


unique_genes <- unique(gene_correlations.separated$gene)
context_context_matrix <- purrr::map(unique_genes, function(ug){
    ccv <- gene_correlations.separated %>%
        dplyr::filter(gene == ug) %>%
        dplyr::select(context1, context2, pearson_r) %>%
        tidyr::pivot_wider(id_cols = context1, names_from = context2, values_from = pearson_r) %>%
        tibble::column_to_rownames('context1') %>%
        as.matrix() %>% round(3)
    ccv <- ccv[gtools::mixedsort(rownames(ccv)), gtools::mixedsort(colnames(ccv))] 
}, .progress = TRUE)

context_context_array <- abind(context_context_matrix, along = 3)
dimnames(context_context_array)[[3]] <- unique_genes

print(dim(context_context_array))
print(context_context_array[1:2, 1:2, 1:2])


saveRDS(context_context_array, '/beagle3/haky/users/temi/projects/dgtex/files/dGTEX-vs-aGTEx.correlation.each_gene.rds.gz', compress = TRUE)