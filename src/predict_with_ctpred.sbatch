#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=12
#SBATCH --mem-per-cpu=12G
#SBATCH --job-name=predict_ctpred
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/predict_ctpred.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/predict_ctpred.err
#SBATCH --time=24:00:00
#SBATCH --partition=bigmem

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/scPrediXcan_env
module load cudnn

list_of_individuals=${1}
module load parallel/

#nvidia-smi
parallel -j 20 --joblog /beagle3/haky/users/temi/projects/dgtex/logs/predict_with_ctpred_per_individual.log "python3 /beagle3/haky/users/temi/projects/dgtex/src/predict_with_ctpred.py \
    --parameters_file ${2} \
    --individual {} \
    --output_directory ${3}" :::: ${list_of_individuals}
    # --cell_file '/beagle3/haky/users/temi/projects/dgtex/files/dgtex_tpm.ctpred_training.adipose_12_18.trial.expression.csv'


    # SBATCH --gres=gpu:1

# SBATCH --account=beagle3-exusers