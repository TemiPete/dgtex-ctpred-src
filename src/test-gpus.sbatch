#!/bin/bash
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --job-name=testing_gpus
#SBATCH --account=beagle3-exusers
#SBATCH --output=./testing_gpus.out
#SBATCH --error=./testing_gpus.err
#SBATCH --time=00:02:00	
#SBATCH --partition=beagle3
#SBATCH --gres=gpu:1

date
printf "Starting to run\n"
source ~/.bashrc
module load cudnn
nvidia-smi