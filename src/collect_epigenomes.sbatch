#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --job-name=collect_epigenomes
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/collect_epigenomes.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/collect_epigenomes.err
#SBATCH --time=00:30:00	
#SBATCH --partition=caslake

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/scPrediXcan_env

python3 '/beagle3/haky/users/temi/projects/dgtex/src/merge_epigenomes.py' \
    --epigenome_file "/beagle3/haky/users/temi/projects/dgtex/files/geuvadis_individuals.epigenomes.tsv" \
    # --output_directory "/beagle3/haky/users/temi/projects/dgtex/data/geuvadis_epigenomes"