#!/bin/bash
# Run AMRFinderPlus on plasmid contigs identified by MOB-recon
# Usage: bash scripts/run_amrfinder.sh

source config/params.sh

for sample_dir in ${RESULTS_DIR}/*/; do
    sample=$(basename $sample_dir)
    for plasmid in ${sample_dir}plasmid_*.fasta; do
        [ -f "$plasmid" ] || continue
        plasmid_name=$(basename $plasmid .fasta)
        echo "Running AMRFinderPlus on ${sample} ${plasmid_name}..."
        amrfinder \
            --nucleotide $plasmid \
            --database ${AMR_DB} \
            --output ${RESULTS_DIR}/${sample}/${plasmid_name}_amrfinder.tsv \
            --threads ${THREADS} \
            --plus
    done
done

echo "AMRFinderPlus complete"
