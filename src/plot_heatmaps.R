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
library(ComplexHeatmap)
library(RColorBrewer)


context_context_array <- readRDS('/beagle3/haky/users/temi/projects/dgtex/files/dGTEX-vs-aGTEx.correlation.each_gene.rds.gz')


out <- purrr::map(dimnames(context_context_array)[[3]], function(agene){
    ccv <- context_context_array[, , agene]
    ccvhtmp <- ComplexHeatmap::Heatmap(mat = ccv, column_title = agene, col = brewer.pal(n = 8, name = "Reds"), border = 'black', cluster_rows = F, cluster_columns = F, column_names_rot = 90, heatmap_legend_param = list(title = expression("")), row_names_gp = gpar(fontsize = 5, fontfamily = 'Helvetica'), column_names_gp = gpar(fontsize = 5, fontfamily = 'Helvetica'), rect_gp = gpar(col = "black", lwd = 0.2), cell_fun = function(j, i, x, y, width, height, fill) {
                grid.text(sprintf("%.3f", ccv[i, j]), x, y, gp = gpar(fontsize = 3))
            })

    pdf(file=glue::glue("/beagle3/haky/users/temi/projects/dgtex/figures/agtex_dgtex_correlations/context_context/dgtex-agtex-in-1000G.{agene}.context_correlation.pdf"), width = 14, height = 10)
    ComplexHeatmap::draw(ccvhtmp)
    dev.off()

}, .progress = TRUE)
