#!/bin/bash
# Run MOB-recon on all assemblies
# Usage: bash scripts/run_mobrecon.sh

source config/params.sh

mkdir -p ${RESULTS_DIR}

#build AWS profile flag only if AWS_PROFILE_NAME is set
PROFILE_FLAG=""
if [ -n "${AWS_PROFILE_NAME}" ]; then
    PROFILE_FLAG="--profile ${AWS_PROFILE_NAME}"
fi

# Autodetect if input is S3 or local directory
if [[ "${INPUT_PATH}" == s3://* ]]; then
    echo "S3 path detected, syncing assemblies..."
    [ -n "${AWS_PROFILE_NAME}" ] && echo "Using AWS profile:" "${AWS_PROFILE_NAME}"
    mkdir -p ${LOCAL_ASSEMBLIES_DIR}
    ASSEMBLIES_DIR=${LOCAL_ASSEMBLIES_DIR}
    aws s3 sync ${PROFILE_FLAG} ${INPUT_PATH} ${ASSEMBLIES_DIR}/
    
else
    echo "Local path detected, using ${INPUT_PATH}..."
    ASSEMBLIES_DIR=${INPUT_PATH}
fi

for fasta in ${ASSEMBLIES_DIR}/*.fna ${ASSEMBLIES_DIR}/*.fasta ${ASSEMBLIES_DIR}/*.fa; do
    [-e "$fasta" ] || continue
    sample=$(basename "$fasta")
    sample="${sample%.fna}"
    sample="${sample%.fasta}"
    sample="${sample%.fa}"
    echo "Processing $sample..."
    mob_recon \
        --infile $fasta \
        --outdir ${RESULTS_DIR}/${sample} \
        --num_threads ${THREADS}
done

echo "MOB-recon complete"
