#!/bin/bash
# Author: Temi
# Description: Predict using GREx component
# Usage: sbatch predict_baca_with_cwas.sbatch
# Date: Mon July 24 2023
# Dependencies: 

#SBATCH --nodes=3
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --job-name=linearize_ctpred
#SBATCH --account=pi-haky
#SBATCH --output=/beagle3/haky/users/temi/projects/dgtex/logs/linearize_ctpred.out
#SBATCH --error=/beagle3/haky/users/temi/projects/dgtex/logs/linearize_ctpred.err
#SBATCH --time=36:00:00	
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
module load parallel/
echo "INFO - using this mpirun: `which mpirun`"

tissues_list=${1}
base_out=${2}
pred_dir=${3}
snp_genotypes=${4}
snp_annotation=${5}
nextflow_executable=${6}

mkdir -p ${base_out}

srun hostname > ./local_hostfiles.txt
#printf "%s\n" "${nodelist[@]}" > ./local_hostfiles.txt

function linearize () {
    tissue=${1}
    outputDirectory=${2}
    filesDirectory=${3}
    txtGeno=${4}
    txtAnnot=${5}
    executable=${6}
    gene_annotations="${filesDirectory}/${tissue}.ctPred_annotations.tsv"
    predicted="${filesDirectory}/${tissue}.ctPred_predictions.tsv"
    outdir="${outputDirectory}/${tissue}"

    if [[ ! -f "$gene_annotations" || ! -f "$predicted" ]]; then
        echo "Warning: files for ${tissue} not found, skipping"
        continue
    fi

    echo "Submitting job for ${tissue}"
    date
    source ~/.bashrc
    conda activate /beagle3/haky/users/temi/software/conda_envs/predictdb-env
    export JAVA_HOME=/beagle3/haky/users/temi/software/conda_envs/predictdb-env/

    echo "Running PredictDB for ${tissue}"
    mkdir -p "${outdir}" && cd "${outdir}"
    echo "Nextflow at: $(which nextflow)"
    export NXF_DISABLE_CHECK_LATEST=true

    nextflow run "${executable}" \
        --gene_annotation "${gene_annotations}" \
        --snp_annotation "${txtAnnot}" \
        --genotype "${txtGeno}" \
        --gene_exp "${predicted}" \
        --prefix "${tissue}" \
        --outdir "${outdir}" \
        -resume \
        -profile midway3 \
        --nested_cv
}

export -f linearize

parallel --joblog /beagle3/haky/users/temi/projects/dgtex/logs/linearization.log --jobs 1 "mpirun -np 1 --hostfile ./local_hostfile.txt linearize {1} ${base_out} ${pred_dir} ${snp_genotypes} ${snp_annotation} ${nextflow_executable}" :::: ${tissues_list}

# mpirun -np 1 bash -c 

# parallel -j 12 "mpirun -np 1 --hostfile 'local_hostfile.${suf}' bash -c linearize ${} ${base_out} ${pred_dir} ${snp_genotypes} ${snp_annotation} ${nextflow_executable}" :::: 


# --sshloginfile ./local_hostfiles.txt




# # now, run and godspeed
# for suf in `seq 1 ${SLURM_NNODES}`; do
#   (
#     echo "INFO - Job ${suf} running on `cat local_hostfile.${suf}` using db.${suf}"
#     mpirun -np 1 --hostfile "local_hostfile.${suf}" bash -c "linearize ${} ${base_out} ${pred_dir} ${snp_genotypes} ${snp_annotation} ${nextflow_executable}"

#   ) & sleep 1
# done
# wait




# parallelization set up 
# printf '%s\n' ${db_folder}/*.db > ./dbs.txt
# dbs_list=./dbs.txt
# x=`wc -l ${tissues_list} | awk '{print $1}'`
# y=${SLURM_NNODES} 
# ll=$(( ($x + $y - 1) / $y ))

# split --lines="${ll}" --numeric-suffixes=1 --suffix-length=1 "${dbs_list}" "db."

# # prepare nodes
# nodelist=$(scontrol show hostname $SLURM_NODELIST)
# printf "%s\n" "${nodelist[@]}" > local_hostfiles.txt
# # Increase value of suffix-length if more than 99 jobs
# split --lines=1 --numeric-suffixes=1 --suffix-length=1 local_hostfiles.txt "local_hostfile."


# base_out="/scratch/beagle3/rkb7263/dgtex/models"
# pred_dir="/beagle3/haky/data/shared/ctpred_predictions_EUR_geuvadis"
# snp_genotypes="/project2/haky/Data/1000G/formatted_geno/all_chrs.geno.txt"
# snp_annotation="/project2/haky/Data/1000G/formatted_geno/all_chrs.snp_annot.txt"
# nextflow_executable="/scratch/beagle3/rkb7263/dgtex/PredictDb-nextflow/main.nf"