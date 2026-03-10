#!/bin/bash
# Run MOB-recon on all assemblies
# Usage: bash scripts/run_mobrecon.sh

source config/params.sh

mkdir -p ${RESULTS_DIR}

# Autodetect if input is S3 or local directory
if [[ "${INPUT_PATH}" == s3://* ]]; then
    echo "S3 path detected, syncing assemblies..."
    ASSEMBLIES_DIR=~/plasmid-workflow/assemblies
    mkdir -p ${ASSEMBLIES_DIR}
    aws s3 sync ${INPUT_PATH} ${ASSEMBLIES_DIR}/
else
    echo "Local path detected, using ${INPUT_PATH}..."
    ASSEMBLIES_DIR=${INPUT_PATH}
fi

for fasta in ${ASSEMBLIES_DIR}/*.fna; do
    sample=$(basename $fasta .fna)
    echo "Processing $sample..."
    mob_recon \
        --infile $fasta \
        --outdir ${RESULTS_DIR}/${sample} \
        --num_threads ${THREADS}
done

echo "MOB-recon complete"
