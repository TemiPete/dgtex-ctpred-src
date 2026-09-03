#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=6
#SBATCH --mem-per-cpu=6G
#SBATCH --job-name=correlate_predictions_sqlite
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/correlate_predictions_sqlite.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/correlate_predictions_sqlite.err
#SBATCH --time=12:00:00
#SBATCH --partition=caslake

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

db_x=${1}
db_y=${2}
comparisons_txt=${3}
output_directory=${4}
context_col=${5:-context}
table_x=${6:-predicted_expression}
table_y=${7:-predicted_expression}
value_col_x=${8:-predicted_expression}
value_col_y=${9:-predicted_expression}

mkdir -p ${output_directory}

# Each comparison below queries "WHERE ${context_col} = ..." -- without an index that's a
# full table scan every time (hundreds of millions of rows for the dGTEx db), so build the
# index once, serially, before the parallel fan-out starts. Safe to run repeatedly
# (IF NOT EXISTS), and safe if db_x and db_y are the same file. dbX and dbY can hold their
# rows under different table names (e.g. an observed_expression table vs a
# predicted_expression table), so each side is indexed with its own table name.
if command -v sqlite3 &> /dev/null; then
    printf "Ensuring index on %s(%s) in %s\n" "${table_x}" "${context_col}" "${db_x}"
    sqlite3 ${db_x} "CREATE INDEX IF NOT EXISTS idx_${table_x}_${context_col} ON ${table_x}(${context_col});"

    printf "Ensuring index on %s(%s) in %s\n" "${table_y}" "${context_col}" "${db_y}"
    sqlite3 ${db_y} "CREATE INDEX IF NOT EXISTS idx_${table_y}_${context_col} ON ${table_y}(${context_col});"
else
    echo "WARNING - sqlite3 CLI not found on PATH; queries below will fall back to a full table scan per comparison, which will be slow for large tables. Create the indexes manually (e.g. from R: DBI::dbExecute(con, \"CREATE INDEX idx_x ON <table>(<context_col>)\")) and re-run."
fi

module load parallel/

# comparisons_txt: 2-column, tab-separated, no header -- contextX  contextY (same format
# gather_correlations.R's --comparisonsMetadata expects)
parallel -j 20 --joblog /beagle3/haky/users/temi/projects/dgtex/logs/correlate_predictions_sqlite.log --colsep '\t' -a ${comparisons_txt} "Rscript /beagle3/haky/users/temi/projects/dgtex/src/correlate_predictions_sqlite.R \
    --dbX ${db_x} \
    --contextX {1} \
    --dbY ${db_y} \
    --contextY {2} \
    --output_directory ${output_directory} \
    --contextCol ${context_col} \
    --tableX ${table_x} \
    --tableY ${table_y} \
    --valueColX ${value_col_x} \
    --valueColY ${value_col_y}"

status=$?
echo "Exit status is: $status"
