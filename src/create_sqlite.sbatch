#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=12G
#SBATCH --job-name=create_sqlite
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/create_sqlite.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/create_sqlite.err
#SBATCH --time=06:00:00	
#SBATCH --partition=bigmem

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

# mkdir -p ${output_directory}

Rscript /beagle3/haky/users/temi/projects/dgtex/src/create_sqlite.R

status=$?
echo "Exit status is: $status"