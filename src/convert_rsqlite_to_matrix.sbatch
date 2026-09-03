#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G    
#SBATCH --job-name=convert_rsqlite_to_matrix
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/convert_rsqlite_to_matrix.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/convert_rsqlite_to_matrix.err
#SBATCH --time=01:00:00
#SBATCH --partition=caslake

date

source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/renviron

Rscript /beagle3/haky/users/temi/projects/dgtex/src/convert_rsqlite_to_matrix.R \
    --sqlite_database /scratch/beagle3/temi/predictions_db/lctPred-aGTEx-predicted-expression-in-dGTEx.sqlite \
    --value_column predicted_expression \
    --output_file_basename /scratch/beagle3/temi/lctPred-aGTEx-predicted-expression-in-dGTEx

status=$?
echo "Exit status of job is: $status"