#!/bin/bash
# Run AMRFinderPlus on all contigs identified by MOB-recon (plasmid and chromosome)
# Usage: bash scripts/run_amrfinder.sh

source config/params.sh

for sample_dir in ${RESULTS_DIR}/*/; do
    sample=$(basename $sample_dir)

    # Build organism flag if ORGANISM is set in params.sh
    ORGANISM_FLAG-""
    if [ -n "${ORGANISM}" ]; then
        ORGANISM_FLAG="--organism ${ORGANISM}"
        echo "USING ORGANISM: ${ORGANISM}"
    fi
        
    # Run on plasmid bins (plasmid_*.fasta)
    for fasta in ${sample_dir}plasmid_*.fasta; do
        [ -f "$fasta" ] || continue
        contig_name=$(basename $fasta .fasta)
        echo "Running AMRFinderPlus on ${sample} ${contig_name}..."
        amrfinder \
            --nucleotide $fasta \
            --database ${AMR_DB} \
            --output ${RESULTS_DIR}/${sample}/${contig_name}_amrfinder.tsv \
            --threads ${THREADS} \
            ${ORGANISM_FLAG} \
            --plus
    done

    # Run on chromosome contigs
    if [ -f "${sample_dir}chromosome.fasta" ]; then
        echo "Running AMRFinderPlus on ${sample} chromosome..."
        amrfinder \
            --nucleotide ${sample_dir}chromosome.fasta \
            --database ${AMR_DB} \
            --output ${RESULTS_DIR}/${sample}/chromosome_amrfinder.tsv \
            --threads ${THREADS} \
            ${ORGANISM_FLAG} \
            --plus
    fi

done

echo "AMRFinderPlus complete"
