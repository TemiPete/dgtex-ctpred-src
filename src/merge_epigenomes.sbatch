#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --job-name=merge_epigenomes_into_one_database
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/merge_epigenomes_into_one_database.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/merge_epigenomes_into_one_database.err
#SBATCH --time=06:00:00	
#SBATCH --partition=caslake

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/scPrediXcan_env

list_of_individuals="/beagle3/haky/users/temi/projects/dgtex/files/geuvadis_individuals.list" #${1}

module load parallel/

parallel -j 20 --joblog /beagle3/haky/users/temi/projects/dgtex/logs/merge_epigenomes_into_one_database.log "python3 /beagle3/haky/users/temi/projects/dgtex/src/merge_epigenomes.py \
    --individual {}" :::: ${list_of_individuals}

status=$?

echo "Exit status of merging is: $status"

# python3 '/beagle3/haky/users/temi/projects/dgtex/src/merge_epigenomes.py' \
#     --epigenome_file "/beagle3/haky/users/temi/projects/dgtex/files/geuvadis_individuals.epigenomes.tsv" \
    # --output_directory "/beagle3/haky/users/temi/projects/dgtex/data/geuvadis_epigenomes"