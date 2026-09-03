# Author: Temi
# Description: Per-gene Pearson/Spearman correlation across individuals between two
#   expression contexts, each read from a SQLite database (as built in
#   ../../analysis-temi/posts/2025-10-15-creating-rsqlite-db-gtex/index.qmd) instead of a
#   3D-array .rds.gz file. dbX and dbY may use different table/value-column names (e.g.
#   dbX's `observed_expression` table vs dbY's `predicted_expression` table) -- see
#   --tableX/--tableY and --valueColX/--valueColY -- but must share the same
#   --contextCol/--individualCol/--geneCol names. Each side is fetched with a
#   `WHERE context = ...` query rather than loading the whole table, to avoid materializing
#   the full long-format table (hundreds of millions of rows for dGTEx) in memory.
#   Output is written as {contextX}-{contextY}.correlation.tsv.gz, the same shape
#   correlate_ctpred_grex.R produces, so gather_correlations.R/.sbatch work on it unchanged.
# Usage: Rscript correlate_predictions_sqlite.R [options]

suppressPackageStartupMessages(library("optparse"))

option_list <- list(
    make_option("--dbX", help = "SQLite database holding contextX's predicted_expression table"),
    make_option("--contextX", help = "context value to filter for in dbX"),
    make_option("--dbY", help = "SQLite database holding contextY's predicted_expression table (can be the same file as --dbX, e.g. for within-dGTEx comparisons)"),
    make_option("--contextY", help = "context value to filter for in dbY"),
    make_option("--output_directory", type = "character", help = "directory to write {contextX}-{contextY}.correlation.tsv.gz to"),
    make_option("--tableX", default = "predicted_expression", help = "table name in dbX [default: %default]"),
    make_option("--tableY", default = "predicted_expression", help = "table name in dbY [default: %default]"),
    make_option("--contextCol", default = "context", help = "column holding the context/tissue label (same name in dbX and dbY) [default: %default]"),
    make_option("--individualCol", default = "individual", help = "column holding the individual id (same name in dbX and dbY) [default: %default]"),
    make_option("--geneCol", default = "ensembl_id", help = "column holding the gene id (same name in dbX and dbY) [default: %default]"),
    make_option("--valueColX", default = "predicted_expression", help = "column holding the value in dbX, e.g. 'predicted_expression' or 'observed_expression' [default: %default]"),
    make_option("--valueColY", default = "predicted_expression", help = "column holding the value in dbY [default: %default]")
)

opt <- parse_args(OptionParser(option_list = option_list))

outfile <- glue::glue("{opt$output_directory}/{opt$contextX}-{opt$contextY}.correlation.tsv.gz")
if (file.exists(outfile)) {
    warning(glue::glue("NOTE - {outfile} already exists. Quitting..."))
    quit()
}
if (!dir.exists(opt$output_directory)) {
    dir.create(opt$output_directory, recursive = TRUE)
}

library(glue) |> suppressPackageStartupMessages()
library(data.table) |> suppressPackageStartupMessages()
library(tidyverse) |> suppressPackageStartupMessages()
library(DBI) |> suppressPackageStartupMessages()
library(RSQLite) |> suppressPackageStartupMessages()

# fetch one context's rows (individual, gene, value) via an indexed WHERE clause,
# and pivot to the same [individual x gene] matrix shape correlate_ctpred_grex.R
# gets from readRDS(rds)[, , context] -- but without ever loading the full table.
# Run create_predicted_expression_index.R once per database beforehand (see the
# matching .sbatch) so this WHERE clause is fast instead of a full table scan.
fetch_context_matrix <- function(db, context, table, contextCol, individualCol, geneCol, valueCol){
    con <- dbConnect(RSQLite::SQLite(), dbname = db, flags = RSQLite::SQLITE_RO)
    on.exit(dbDisconnect(con))

    query <- glue::glue_sql(
        "SELECT {`individualCol`}, {`geneCol`}, {`valueCol`} FROM {`table`} WHERE {`contextCol`} = {context}",
        .con = con
    )
    long <- dbGetQuery(con, query) %>% stats::setNames(c('individual', 'gene', 'value'))

    long %>%
        tidyr::pivot_wider(id_cols = individual, names_from = gene, values_from = value) %>%
        tibble::column_to_rownames('individual') %>%
        as.matrix()
}

matrixX <- tryCatch({
    fetch_context_matrix(opt$dbX, opt$contextX, opt$tableX, opt$contextCol, opt$individualCol, opt$geneCol, opt$valueColX)
}, error = function(err){
    warning(glue::glue("ERROR - could not fetch context '{opt$contextX}' from {opt$dbX}: {conditionMessage(err)}"))
    quit()
})

matrixY <- tryCatch({
    fetch_context_matrix(opt$dbY, opt$contextY, opt$tableY, opt$contextCol, opt$individualCol, opt$geneCol, opt$valueColY)
}, error = function(err){
    warning(glue::glue("ERROR - could not fetch context '{opt$contextY}' from {opt$dbY}: {conditionMessage(err)}"))
    quit()
})

if (nrow(matrixX) == 0 || nrow(matrixY) == 0) {
    warning(glue::glue("ERROR - context '{opt$contextX}' or '{opt$contextY}' returned no rows -- check the context labels and --contextCol"))
    quit()
}

# with help from Haky -- identical to correlate_ctpred_grex.R, so results are comparable
cor2pval <- function(cc, nn) {
    zz <- atanh(cc) * sqrt(nn - 3)
    pnorm(-abs(zz)) * 2
}

calculate_pearson_correlation_of_two_matrices <- function(ma, mb, matrix_names = c('matrixA', 'matrixB')){
    stopifnot((nrow(ma) == nrow(mb)) & (ncol(ma) == ncol(mb)))
    nterms <- nrow(ma)
    cor_vec <- apply(scale(ma) * scale(mb), 2, sum) / nterms
    p_vec <- cor2pval(cor_vec, nterms)
    dt <- cbind(pearson_r = cor_vec, pearson_pvalue = p_vec) %>% as.data.frame() %>% tibble::rownames_to_column('locus')
    dt$comparison <- paste0(matrix_names[1], ':', matrix_names[2])
    dt %>% dplyr::arrange(desc(abs(pearson_r)))
}

calculate_spearman_correlation_of_two_matrices <- function(ma, mb, matrix_names = c('matrixA', 'matrixB')){
    stopifnot((nrow(ma) == nrow(mb)) & (ncol(ma) == ncol(mb)))
    test_results <- mapply(function(x1, x2){
        test <- cor.test(x1, x2, method = 'spearman', exact = FALSE)
        c(test$p.value, test$estimate)
    }, ma |> as.data.frame(), mb |> as.data.frame())

    test_results %>%
        t() %>%
        as.data.frame() %>%
        stats::setNames(c('spearman_pvalue', 'spearman_r')) %>%
        tibble::rownames_to_column('locus') %>%
        dplyr::mutate(comparison = paste0(matrix_names[1], ':', matrix_names[2]))
}

mat_names <- c(opt$contextX, opt$contextY)
print(glue::glue("INFO - Correlating {mat_names[1]} with {mat_names[2]}"))

common_individuals <- intersect(rownames(matrixX), rownames(matrixY))
common_genes <- intersect(colnames(matrixX), colnames(matrixY))
ma <- matrixX[common_individuals, common_genes, drop = FALSE]
mb <- matrixY[common_individuals, common_genes, drop = FALSE]
print(glue::glue("INFO - {length(common_individuals)} common individuals, {length(common_genes)} common genes"))

pearson_result <- calculate_pearson_correlation_of_two_matrices(ma, mb, mat_names)
spearman_result <- calculate_spearman_correlation_of_two_matrices(ma, mb, mat_names)
result <- dplyr::full_join(pearson_result, spearman_result, by = c('locus', 'comparison')) %>%
    dplyr::select(locus, comparison, spearman_pvalue, spearman_r, pearson_pvalue, pearson_r)

if (nrow(result) > 0) {
    data.table::fwrite(result, outfile, sep = '\t', col.names = TRUE, row.names = FALSE, quote = FALSE, compress = 'gzip')
    print(glue::glue("INFO - Saved {nrow(result)} rows to {outfile}"))
} else {
    print(glue::glue("ERROR - {mat_names[1]} with {mat_names[2]} did not complete successfully"))
}
