# Author: Temi
# Date: Tues Sep 16 2025
# Description: Correlate ctPred predictions with GTEx
# Usage: Rscript train_enet.R [options]

suppressPackageStartupMessages(library("optparse")) |> suppressPackageStartupMessages()

option_list <- list(
    make_option("--rdsX", help='A 3D array, preferrably in rds format'),
    make_option("--matrixX", help='A 3D array, preferrably in rds format'),
    make_option("--matrixY", help='a text file of gtex model predictions'),
    make_option("--output_directory", type="character", help='How many cv folds?'),
    make_option("--directoryY", help='data to train with enet')
)

opt <- parse_args(OptionParser(option_list=option_list))
mat_names <- c(opt$matrixX, opt$matrixY)
outfile <- glue::glue("{opt$output_directory}/{mat_names[1]}-{mat_names[2]}.correlation.tsv.gz")
if(file.exists(outfile)){
    warning(glue::glue("NOTE - {outfile} aleady exists. Quitting..."))
    quit()
}

library(glue) |> suppressPackageStartupMessages()
library(R.utils) |> suppressPackageStartupMessages()
library(data.table) |> suppressPackageStartupMessages()
library(tidyverse) |> suppressPackageStartupMessages()

# dt_comparisons <- data.table::fread(opt$comparison_file)

matrixX <- tryCatch({
    readRDS(opt$rdsX)[, , opt$matrixX]
}, error = function(err){
    warning(glue::glue("ERROR - {opt$matrixX} does not exist in {opt$rdsX}"))
    quit()
})

fileY <- Sys.glob(glue::glue("{opt$directoryY}/*{opt$matrixY}.*.predict.txt"))
if(file.exists(fileY)){
    matrixY <- data.table::fread(fileY) %>%
        dplyr::select(-FID) 
    new_names <- colnames(matrixY) %>% strsplit('\\.') %>% sapply(getElement, 1)
    matrixY <- matrixY %>% 
        data.table::setnames(old = colnames(.), new = new_names) %>% 
        tibble::column_to_rownames('IID') %>% 
        as.matrix()
}

# print(glue("INFO - Dimension of {opt$matrixX} is {dim(matrixX)}"))
# print(glue("INFO - Dimension of {opt$matrixY} is {dim(matrixY)}"))

# with help from Haky
cor2pval <- function(cc,nn) {
  zz = atanh(cc) * sqrt(nn-3)
  pnorm(-abs(zz))*2
}

calculate_pearson_correlation_of_two_matrices <- function(ma, mb, matrix_names = c('matrixA', 'matrixB')){
    # conditions
    if(all((nrow(ma) == nrow(mb)) & (ncol(ma) == ncol(mb)) & identical(rownames(ma), rownames(mb)) & identical(colnames(ma), colnames(mb)))){
        nterms <- nrow(ma)
        cor_vec <- apply(scale(ma) * scale(mb), 2, sum)/nterms
        p_vec <- cor2pval(cor_vec, nterms)
        dt <- cbind(pearson_r=cor_vec, pearson_pvalue=p_vec) %>% as.data.frame() %>% tibble::rownames_to_column('locus')
        dt$comparison <- paste0(matrix_names[1], ':', matrix_names[2])
        dt <- dt %>% dplyr::arrange(desc(abs(pearson_r)))
        return(dt) 
    } else {
        stop("ERROR - Dimensions or names of input matrices are not the same")
    }
}


calculate_spearman_correlation_of_two_matrices <- function(ma, mb, matrix_names = c('matrixA', 'matrixB')){

    if(all((nrow(ma) == nrow(mb)) & (ncol(ma) == ncol(mb)) & identical(rownames(ma), rownames(mb)) & identical(colnames(ma), colnames(mb)))){
        test_results <- mapply(function(x1, x2){
            test <- cor.test(x1, x2, method = 'spearman', exact=FALSE)
            return(c(test$p.value, test$estimate))
        }, ma |> as.data.frame(), mb |> as.data.frame())
    
        dt <- test_results %>% t() %>% 
            as.data.frame() %>% 
            stats::setNames(nm = c('spearman_pvalue', 'spearman_r')) %>% 
            tibble::rownames_to_column('locus')
        dt$comparison <- paste0(matrix_names[1], ':', matrix_names[2])
        return(dt)
    } else {
        stop("ERROR - Dimensions or names of input matrices are not the same")
    }
}

mat_names <- c(opt$matrixX, opt$matrixY)
print(glue::glue("INFO - Correlating {mat_names[1]} with {mat_names[2]}"))
common_colnames <- intersect(colnames(matrixX), colnames(matrixY))
common_rownames <- intersect(rownames(matrixX), rownames(matrixY))
ma <- matrixX[common_rownames, common_colnames]
mb <- matrixY[common_rownames, common_colnames]
pearson_result <- calculate_pearson_correlation_of_two_matrices(ma, mb, mat_names)
spearman_result <- calculate_spearman_correlation_of_two_matrices(ma, mb, mat_names)
result <- dplyr::full_join(pearson_result, spearman_result, by = c('locus', 'comparison')) %>%
    dplyr::select(locus, comparison, spearman_pvalue, spearman_r, pearson_pvalue, pearson_r)

if(nrow(result) > 0){
    data.table::fwrite(result, outfile, sep = '\t', col.names = T, row.names = F, quote = F, compress = 'gzip')
} else {
    print('ERROR - {mat_names[1]} with {mat_names[2]} did not complete successfully')
}