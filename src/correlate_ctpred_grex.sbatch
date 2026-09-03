#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=12G
#SBATCH --job-name=correlate_ctpred_grex
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/correlate_ctpred_grex.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/correlate_ctpred_grex.err
#SBATCH --time=04:00:00	
#SBATCH --partition=bigmem

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

input_rds=${1}
# name_matrixX=${2}
# name_matrixY=${3}
output_directory=${2}
comparisons_txt=${3}
matrixY_directory=${4}

mkdir -p ${output_directory}

module load parallel/

parallel -j 25 --joblog /beagle3/haky/users/temi/projects/dgtex/logs/correlate_ctpred_grex.log --colsep '\t' -a ${comparisons_txt} "Rscript /beagle3/haky/users/temi/projects/dgtex/src/correlate_ctpred_grex.R \
    --rdsX ${input_rds} \
    --matrixX {1} \
    --matrixY {2} \
    --output_directory ${output_directory} \
    --directoryY ${matrixY_directory}"

status=$?
echo "Exit status is: $status"