#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=12G
#SBATCH --job-name=make_umap_data
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/make_umap_data.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/make_umap_data.err
#SBATCH --time=06:00:00	
#SBATCH --partition=bigmem

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

Rscript /beagle3/haky/users/temi/projects/dgtex/src/make_umap_data.R --input_data ${1} --output_file_basename ${2} --top_n_most_variable ${3}

status=$?
echo "Exit status is: $status"