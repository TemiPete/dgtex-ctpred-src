#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=12G
#SBATCH --job-name=correlate_lctpred_predictions
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/correlate_lctpred_predictions.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/correlate_lctpred_predictions.err
#SBATCH --time=06:00:00	
#SBATCH --partition=caslake

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

mkdir -p ${output_directory}

Rscript /beagle3/haky/users/temi/projects/dgtex/src/correlate_lctpred_predictions.R \
    --matrixX ${1} \
    --matrixY ${2} \
    --output_file_basename ${3}

status=$?
echo "Exit status is: $status"