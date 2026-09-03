#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --job-name=correlate_observed_expression
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/correlate_observed_expression.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/correlate_observed_expression.err
#SBATCH --time=04:00:00	
#SBATCH --partition=caslake

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

# mkdir -p ${output_directory}

Rscript /beagle3/haky/users/temi/projects/dgtex/src/correlate_observed_expression.R \
    --matrixX ${1} \
    --matrixY ${2} \
    --output_file_basename ${3} \
    --names ${4}

status=$?
echo "Exit status is: $status"