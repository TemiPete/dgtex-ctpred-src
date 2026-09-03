#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --job-name=plot_heatmaps
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/plot_heatmaps.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/plot_heatmaps.err
#SBATCH --time=12:00:00	
#SBATCH --partition=caslake

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

Rscript /beagle3/haky/users/temi/projects/dgtex/src/plot_heatmaps.R

status=$?
echo "Exit status is: $status"