#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=8G
#SBATCH --job-name=train_ctpred
#SBATCH --account=beagle3-exusers
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/train_ctpred.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/train_ctpred.err
#SBATCH --time=06:00:00	
#SBATCH --partition=beagle3
#SBATCH --gres=gpu:1

date
printf "Starting to run\n"
source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/scPrediXcan_env
module load cudnn


nvidia-smi

python '/beagle3/haky/users/temi/projects/dgtex-ctpred-src/src/ctpred/ctPred_train.py' \
    --parameters ${1} \
    --data_dir ${2} \
    --metrics_file ${3}
    # --cell_file '/beagle3/haky/users/temi/projects/dgtex/files/dgtex_tpm.ctpred_training.adipose_12_18.trial.expression.csv'


# sinteractive --partition=beagle3 --gres=gpu:1 --account=beagle3-exusers --time=01:00:00