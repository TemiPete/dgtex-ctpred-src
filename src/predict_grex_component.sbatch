#!/bin/bash

# Author: Temi
# Description: Predict using GREx component
# Usage: sbatch predict_baca_with_cwas.sbatch
# Date: Mon July 24 2023
# Dependencies: 

#SBATCH --nodes=7
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --job-name=predict_grex
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/predict_grex.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/predict_grex.err
#SBATCH --time=02:00:00	
#SBATCH --partition=caslake

date 
echo $SLURM_O_WORKDIR

SLURM_O_WORKDIR=${SLURM_SUBMIT_DIR}/run
mkdir -p ${SLURM_O_WORKDIR}
echo Working directory is $SLURM_O_WORKDIR
cd $SLURM_O_WORKDIR

echo Jobid: $SLURM_JOBID
echo Running on host `hostname`

printf "Starting to run\n"

source ~/.bashrc
conda activate /beagle3/haky/users/temi/software/conda_envs/imlabtools 
module load openmpi
echo "INFO - using this mpirun: `which mpirun`"

# paths
db_folder=${1}
txt_genotypes=${2}
txt_samples=${3}
exec_file=${4}
output_folder=${5}
dbs_list=${6}

mkdir -p ${output_folder}

# parallelization set up 
# printf '%s\n' ${db_folder}/*.db > ./dbs.txt
# dbs_list=./dbs.txt
x=`wc -l ${dbs_list} | awk '{print $1}'`
y=${SLURM_NNODES} 
ll=$(( ($x + $y - 1) / $y ))

split --lines="${ll}" --numeric-suffixes=1 --suffix-length=1 "${dbs_list}" "db."

# prepare nodes
nodelist=$(scontrol show hostname $SLURM_NODELIST)
printf "%s\n" "${nodelist[@]}" > local_hostfiles.txt
# Increase value of suffix-length if more than 99 jobs
split --lines=1 --numeric-suffixes=1 --suffix-length=1 local_hostfiles.txt "local_hostfile."

# the predict function is defined here
function predict () {
    execFile=${1}
    dbFolder=${2}
    dbList=${3}
    txtGeno=${4}
    txtIds=${5}
    outFolder=${6}

    readarray -t arrr < ${dbList}

    for m_name in ${arrr[@]}; do
        model=$( echo "${dbFolder}/*${m_name}.db" ) #$( echo ${model_db} | rev | cut -d '/' -f 1 | cut -d '_' -f 1 | rev )
        #m_name=${m_name%.*}
        echo "INFO - Running ${m_name}"

        # if [[ ${m_name} != 'top1' ]]; then
        #     continue
        # else
        python ${execFile} \
        --model_db_path ${model} \
        --text_genotypes ${txtGeno} \
        --text_sample_ids ${txtIds} \
        --prediction_output "${outFolder}/${m_name}.geuvadis.predict.txt" \
        --prediction_summary_output "${outFolder}/${m_name}.geuvadis.summary.txt" \
        --verbosity 9 \
        --model_db_snp_key varID \
        --throw  
    done
    wait
}

export -f predict

# now, run and godspeed
for suf in `seq 1 ${SLURM_NNODES}`; do
  (
    echo "INFO - Job ${suf} running on `cat local_hostfile.${suf}` using db.${suf}"
    mpirun -np 1 --hostfile "local_hostfile.${suf}" bash -c "predict ${exec_file} ${db_folder} db.${suf} ${txt_genotypes} ${txt_samples} ${output_folder}"

  ) & sleep 1
done
wait



# --prediction_output "${outFolder}/${m_name}.geuvadis.predict.txt" \
#         --prediction_summary_output "${outFolder}/${m_name}.geuvadis.summary.txt" \