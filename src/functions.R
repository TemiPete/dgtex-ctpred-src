


# calculate_spearman_correlation_of_two_matrices <- function(ma, mb, matrix_names){
#     stopifnot(identical(rownames(ma), rownames(mb)))
#     test_results <- mapply(function(x1, x2){
#         test <- cor.test(x1, x2, method = "spearman", exact = FALSE)
#         c(test$p.value, test$estimate)
#     }, split(ma, row(ma)), split(mb, row(mb)))

#     test_results %>%
#         t() %>%
#         as.data.frame() %>%
#         stats::setNames(c("spearman_pvalue", "spearman_r")) %>%
#         dplyr::mutate(gene = rownames(ma), comparison = paste0(matrix_names[1], ":", matrix_names[2]))
# }



fetch_muscle_long <- function(db, table, value_col){
    con <- DBI::dbConnect(RSQLite::SQLite(), db, flags = RSQLite::SQLITE_RO)
    on.exit(DBI::dbDisconnect(con))
    query <- glue::glue_sql(
        "SELECT individual, ensembl_id AS gene, {`value_col`} AS value, context FROM {`table`} WHERE context LIKE 'Muscle%'",
        .con = con
    )
    DBI::dbGetQuery(con, query) %>% data.table::as.data.table()
}

# collapse_age = TRUE averages across muscle age cohorts per individual (needed whenever
# the other side of the comparison has no age dimension); collapse_age = FALSE keeps each
# age cohort as its own sample, for pairing against a source with the same age cohorts.
muscle_matrix <- function(long, collapse_age = TRUE){
    long %>%
        dplyr::mutate(sample_id = if (collapse_age) individual else paste0(individual, "_", sub("^Muscle_", "", context))) %>%
        dplyr::group_by(sample_id, gene) %>%
        dplyr::summarize(value = mean(value), .groups = "drop") %>%
        tidyr::pivot_wider(id_cols = gene, names_from = sample_id, values_from = value) %>%
        tibble::column_to_rownames("gene") %>%
        as.matrix()
}


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

calculate_spearman_correlation_of_two_matrices <- function(ma, mb, matrix_names = c('matrixA', 'matrixB')){

    if(all((nrow(ma) == nrow(mb)) & (ncol(ma) == ncol(mb)) & identical(rownames(ma), rownames(mb)) & identical(colnames(ma), colnames(mb)))){
        test_results <- mapply(function(x1, x2){
            test <- cor.test(x1, x2, method = 'spearman', exact=FALSE)
            return(c(test$p.value, test$estimate))
        }, split(ma, row(ma)), split(mb, row(mb)))
        #split(ma |> as.data.frame(), mb |> as.data.frame())
    
        dt <- test_results %>% 
            t() %>% 
            as.data.frame() %>% 
            dplyr::mutate(gene = rownames(ma)) %>%
            stats::setNames(nm = c('spearman_pvalue', 'spearman_r', 'gene')) 
        dt$comparison <- paste0(matrix_names[1], ':', matrix_names[2])
        return(dt)
    } else {
        stop("ERROR - Dimensions or names of input matrices are not the same")
    }
}

correlate_muscle <- function(configX, configY, matrix_names, collapse_age = TRUE){
    matX <- fetch_muscle_long(configX$db, configX$table, configX$value_col) %>% muscle_matrix(collapse_age)
    matY <- fetch_muscle_long(configY$db, configY$table, configY$value_col) %>% muscle_matrix(collapse_age)

    common_genes <- intersect(rownames(matX), rownames(matY))
    common_individuals <- intersect(colnames(matX), colnames(matY))
    matX <- matX[common_genes, common_individuals]
    matY <- matY[common_genes, common_individuals]

    calculate_spearman_correlation_of_two_matrices(matX, matY, matrix_names) %>%
        dplyr::filter(!is.na(spearman_r)) %>%
        na.omit() %>%
        as.data.table()
}


# calculate_spearman_correlation_of_two_matrices <- function(ma, mb, matrix_names = c('matrixA', 'matrixB')){

#     if(all((nrow(ma) == nrow(mb)) & (ncol(ma) == ncol(mb)) & identical(rownames(ma), rownames(mb)) & identical(colnames(ma), colnames(mb)))){
#         test_results <- mapply(function(x1, x2){
#             test <- cor.test(x1, x2, method = 'spearman', exact=FALSE)
#             return(c(test$p.value, test$estimate))
#         }, split(ma, row(ma)), split(mb, row(mb)))
#         #split(ma |> as.data.frame(), mb |> as.data.frame())
    
#         dt <- test_results %>% 
#             t() %>% 
#             as.data.frame() %>% 
#             dplyr::mutate(gene = rownames(ma)) %>%
#             stats::setNames(nm = c('spearman_pvalue', 'spearman_r', 'gene')) 
#         dt$comparison <- paste0(matrix_names[1], ':', matrix_names[2])
#         return(dt)
#     } else {
#         stop("ERROR - Dimensions or names of input matrices are not the same")
#     }
# }


# calculate_spearman_correlation_of_two_matrices <- function(ma, mb, matrix_names = c('matrixA', 'matrixB')){

#     if(all((nrow(ma) == nrow(mb)) & (ncol(ma) == ncol(mb)) & identical(rownames(ma), rownames(mb)) & identical(colnames(ma), colnames(mb)))){
#         test_results <- mapply(function(x1, x2){
#             test <- cor.test(x1, x2, method = 'spearman', exact = FALSE)
#             return(c(test$p.value, test$estimate))
#         }, split(ma, row(ma)), split(mb, row(mb)))

#         dt <- test_results %>%
#             t() %>%
#             as.data.frame() %>%
#             dplyr::mutate(gene = rownames(ma)) %>%
#             stats::setNames(nm = c('spearman_pvalue', 'spearman_r', 'gene'))
#         dt$comparison <- paste0(matrix_names[1], ':', matrix_names[2])
#         return(dt)
#     } else {
#         stop("ERROR - Dimensions or names of input matrices are not the same")
#     }
# }