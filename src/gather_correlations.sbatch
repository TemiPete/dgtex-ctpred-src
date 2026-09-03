#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=12G
#SBATCH --job-name=gather_correlations
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/gather_correlations.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/gather_correlations.err
#SBATCH --time=00:45:00
#SBATCH --partition=caslake

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

Rscript /beagle3/haky/users/temi/projects/dgtex/src/gather_correlations.R \
    --comparisonsMetadata ${1} \
    --outputDirectory ${2} \
    --comparisonsDirectory ${3} \
    --collectWhat ${4}

status=$?
echo "Exit status is: $status"