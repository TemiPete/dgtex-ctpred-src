# Author: Temi
# Date: Tues Sep 16 2025
# Description: Correlate ctPred predictions with GTEx
# Usage: Rscript train_enet.R [options]

suppressPackageStartupMessages(library("optparse")) |> suppressPackageStartupMessages()

option_list <- list(
    make_option("--matrixX", help='A dataframe or matrix, preferrably in table format'),
    make_option("--matrixY", help='A dataframe or matrix, preferrably in table format'),
    make_option("--output_file_basename", type="character", help='File name will be extended'),
    make_option("--names", type="character", default = c("aGTEx,dGTEx"), help='File name will be extended')
)

opt <- parse_args(OptionParser(option_list=option_list))

outfile_gene <- glue::glue("{opt$output_file_basename}.tsv.gz")

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
    data.table::fread(opt$matrixX) %>% tibble::column_to_rownames(colnames(.)[1]) %>% as.matrix()
}, error = function(err){
    warning(glue::glue("ERROR - {opt$matrixX} does not exist"))
    quit()
})

matrixY <- tryCatch({
    data.table::fread(opt$matrixY) %>% tibble::column_to_rownames(colnames(.)[1]) %>% as.matrix()
}, error = function(err){
    warning(glue::glue("ERROR - {opt$matrixY} does not exist"))
    quit()
})


# get common observations
common_observations <- intersect(rownames(matrixX), rownames(matrixY))
length(common_observations)

matrixX <- matrixX[common_observations, ]
matrixY <- matrixY[common_observations, ]

print(dim(matrixX))
print(dim(matrixY))

print(matrixX[1:3, 1:3])
print(matrixY[1:3, 1:3])

data_names <- strsplit(opt$names, ',')[[1]]


possible_context_comparisons <- expand_grid(colnames(matrixX), colnames(matrixY)) %>%
    setnames(data_names)

print(glue::glue("INFO - Found {nrow(possible_context_comparisons)} comparisons to make"))


correlations <- purrr::map2(.x = possible_context_comparisons[[data_names[1]]], .y = possible_context_comparisons[[data_names[2]]], function(x, y){
    out <- tryCatch({
        cortest <- cor.test(matrixX[, x], abs(matrixY[, y]))
        c(as.numeric(cortest$estimate), cortest$p.value)
    }, error = function(e){
        c(NA, NA)
    }) 
}, .progress = TRUE) %>%
    do.call('rbind', .) %>%
    as.data.table() %>%
    setnames(c('corr', 'pvalue'))

correlations <- cbind(possible_context_comparisons, correlations)

print(head(correlations))

if(nrow(correlations) > 0){
    data.table::fwrite(correlations, outfile_gene, sep = '\t', col.names = T, row.names = F, quote = F, compress = 'gzip')
} else {
    print('ERROR - Correlations did not complete successfully')
}

