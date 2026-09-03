suppressPackageStartupMessages(library("optparse")) |> suppressPackageStartupMessages()

option_list <- list(
    make_option("--comparisonsMetadata", help='A 3D array, preferrably in rds format'),
    make_option("--outputDirectory", type="character", help='How many cv folds?'),
    make_option("--comparisonsDirectory", help='data to train with enet'),
    make_option("--collectWhat", help='data to train with enet')
)

opt <- parse_args(OptionParser(option_list=option_list))

library(tidyverse)
library(glue)
library(data.table)

outfile <- glue::glue("{opt$outputDirectory}/{opt$collectWhat}.matrix.tsv.gz")

if(!dir.exists(opt$outputDirectory)){
    dir.create(opt$outputDirectory, recursive = TRUE)
}

if(file.exists(outfile)){
    warning(glue::glue("NOTE - {outfile} aleady exists. Quitting..."))
    quit()
}
dt_comparisons <- data.table::fread(opt$comparisonsMetadata, header = F)

out_matrix <- purrr::map(1:nrow(dt_comparisons), function(i){
    corrfile <- file.path(opt$comparisonsDirectory, glue::glue("{dt_comparisons$V1[i]}-{dt_comparisons$V2[i]}.correlation.tsv.gz"))
    if(file.exists(corrfile)){
        dtx <- data.table::fread(corrfile) %>% 
            dplyr::select(locus, all_of(opt$collectWhat), comparison) %>% 
            tidyr::pivot_wider(id_cols = locus, names_from = comparison, values_from = all_of(opt$collectWhat))
        return(dtx)
    }
}, .progress = TRUE)

out_matrix <- Filter(Negate(is.null), out_matrix)

print(message(glue::glue("INFO - Collected {length(out_matrix)} matrices")))

dt_out <- out_matrix %>% purrr::reduce(full_join, by = "locus") %>% dplyr::relocate(locus)
print(message(glue::glue("INFO - Joined all matrices")))
data.table::fwrite(dt_out, outfile, quote = F, row.names = F, col.names = T, compress = 'gzip', sep = '\t')
print(message(glue::glue("INFO - Saved output to {outfile}")))