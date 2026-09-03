# Author: Temi
# Date: Tues Sep 16 2025
# Description: Correlate ctPred predictions with GTEx
# Usage: Rscript train_enet.R [options]

suppressPackageStartupMessages(library("optparse")) |> suppressPackageStartupMessages()

option_list <- list(
    make_option("--matrixX", help='A 3D array, preferrably in rds format'),
    make_option("--matrixY", help='A 3D array, preferrably in rds format'),
    make_option("--output_file_basename", type="character", help='How many cv folds?')
)

opt <- parse_args(OptionParser(option_list=option_list))
outfile_individual <- glue::glue("{opt$output_file_basename}.individuals.correlation.tsv.gz")
outfile_gene <- glue::glue("{opt$output_file_basename}.genes.correlation.tsv.gz")
if(file.exists(outfile_individual)){
    warning(glue::glue("NOTE - {outfile_individual} aleady exists. Quitting..."))
    quit()
}

if(file.exists(outfile_gene)){
    warning(glue::glue("NOTE - {outfile_gene} aleady exists. Quitting..."))
    quit()
}

library(glue) |> suppressPackageStartupMessages()
library(R.utils) |> suppressPackageStartupMessages()
library(data.table) |> suppressPackageStartupMessages()
library(tidyverse) |> suppressPackageStartupMessages()

# dt_comparisons <- data.table::fread(opt$comparison_file)

matrixX <- tryCatch({
    readRDS(opt$matrixX)
}, error = function(err){
    warning(glue::glue("ERROR - {opt$matrixX} does not exist"))
    quit()
})


matrixY <- tryCatch({
    readRDS(opt$matrixY)
}, error = function(err){
    warning(glue::glue("ERROR - {opt$matrixY} does not exist"))
    quit()
})


# with help from Haky

cor2pval <- function(cc,nn) {
  zz = atanh(cc) * sqrt(nn-3)
  pnorm(-abs(zz))*2
}

calculate_pearson_correlation_of_two_matrices <- function(ma, mb, matrix_names = c('matrixA', 'matrixB'), merge_row_names = FALSE){
    # conditions: identical(rownames(ma), rownames(mb)) & identical(colnames(ma), colnames(mb))
    if(all((nrow(ma) == nrow(mb)) & (ncol(ma) == ncol(mb)))){
        nterms <- nrow(ma)
        cor_vec <- apply(scale(ma) * scale(mb), 2, sum)/nterms
        p_vec <- cor2pval(cor_vec, nterms)
        dt <- cbind(pearson_r=cor_vec, pearson_pvalue=p_vec) %>% as.data.frame() %>% tibble::rownames_to_column('locus')
        if(merge_row_names == TRUE){
            compnames <- paste0(colnames(ma), ":", colnames(mb))
            dt$comparison <- compnames #paste0(matrix_names[1], ':', matrix_names[2])
        } else {
            dt$comparison <- paste0(matrix_names[1], ':', matrix_names[2])
        }
        dt <- dt %>% dplyr::arrange(desc(abs(pearson_r)))
        return(dt) 
    } else {
        stop("ERROR - Dimensions or names of input matrices are not the same")
    }
}

possible_context_comparisons <- expand_grid(colnames(matrixX), colnames(matrixY)) %>%
    setnames(c("aGTEx_context", "dGTEx_context"))

print(glue::glue("INFO - Found {nrow(possible_context_comparisons)} comparisons to make"))

individual_correlations <- purrr::map2(.x = possible_context_comparisons$aGTEx_context, .y = possible_context_comparisons$dGTEx_context, function(x, y){
    calculate_pearson_correlation_of_two_matrices(matrixX[, x, ], matrixY[, y, ], matrix_names = c(x, y), merge_row_names = FALSE)
}) %>%
    do.call('rbind', .) %>%
    dplyr::rename(individual = locus)

if(nrow(individual_correlations) > 0){
    data.table::fwrite(individual_correlations, outfile_individual, sep = '\t', col.names = T, row.names = F, quote = F, compress = 'gzip')
} else {
    print('ERROR - Individual correlations did not complete successfully')
}

gene_correlations <- purrr::map2(.x = possible_context_comparisons$aGTEx_context, .y = possible_context_comparisons$dGTEx_context, function(x, y){
    calculate_pearson_correlation_of_two_matrices(t(matrixX[, x, ]), t(matrixY[, y, ]), matrix_names = c(x, y), merge_row_names = FALSE)
}) %>%
    do.call('rbind', .) %>%
    dplyr::rename(gene = locus)

if(nrow(gene_correlations) > 0){
    data.table::fwrite(gene_correlations, outfile_gene, sep = '\t', col.names = T, row.names = F, quote = F, compress = 'gzip')
} else {
    print('ERROR - Gene correlations did not complete successfully')
}

