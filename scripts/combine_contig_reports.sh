#!/bin/bash
# Combine all MOB-recon contig_report.txt files into one TSV
# Usage: bash scripts/combine_contig_reports.sh <results_dir> <output_file>

RESULTS_DIR=${1:-results}
OUTPUT_FILE=${2:-combined_contig_report.tsv}

first_file=$(find $RESULTS_DIR -name "contig_report.txt" | head -1)
echo -e "sample\t$(head -1 $first_file)" > $OUTPUT_FILE

for f in $RESULTS_DIR/*/contig_report.txt; do
    sample=$(basename $(dirname $f))
    tail -n +2 $f | while IFS= read -r line; do
        echo -e "${sample}\t${line}"
    done
done >> $OUTPUT_FILE

echo "Done — written to $OUTPUT_FILE"
echo "Samples included: $(tail -n +2 $OUTPUT_FILE | cut -f1 | sort -u | wc -l)"
echo "Total contigs: $(tail -n +2 $OUTPUT_FILE | wc -l)"
