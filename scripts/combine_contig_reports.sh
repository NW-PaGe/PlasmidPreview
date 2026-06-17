#!/bin/bash
# Combine all MOB-recon contig_report.txt files into one TSV
# Usage: bash scripts/combine_contig_reports.sh <results_dir> <output_file>

source config/params.sh

RESULTS_DIR=${1:-${RESULTS_DIR}}
OUTPUT_FILE=${2:-combined_contig_report.tsv}

first_file=$(find $RESULTS_DIR -name "contig_report.txt" | head -1)
echo -e "sample\t$(head -1 $first_file)" > $OUTPUT_FILE

total_contigs=0
chromosome_contigs=0
plasmid_contigs=0
declare -A seen_samples

for f in $RESULTS_DIR/*/contig_report.txt; do
    sample=$(basename $(dirname $f))
    seen_samples[$sample]=1

    while IFS=$'\t' read -r -a fields; do
        molecule_type="${fields[1]}"
        echo -e "${sample}\t$(IFS=$'\t'; echo "${fields[*]}")" >> $OUTPUT_FILE
        ((total_contigs++))
        [[ "$molecule_type" == "chromosome" ]] && ((chromosome_contigs++))
        [[ "$molecule_type" == "plasmid" ]]    && ((plasmid_contigs++))
    done < <(tail -n +2 $f)

done

echo "Done — written to $OUTPUT_FILE"
echo "Samples included:    ${#seen_samples[@]}"
echo "Total contigs:       $total_contigs"
echo "Chromosome contigs:  $chromosome_contigs"
echo "Plasmid contigs:     $plasmid_contigs"
