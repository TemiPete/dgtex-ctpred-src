#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --job-name=prepare_context_by_context
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/prepare_context_by_context.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/prepare_context_by_context.err
#SBATCH --time=06:00:00	
#SBATCH --partition=caslake

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

Rscript /beagle3/haky/users/temi/projects/dgtex/src/prepare_context_by_context.R

status=$?
echo "Exit status is: $status"