#!/bin/bash
# Combine all AMRFinderPlus output files into one TSV
# Usage: bash scripts/combine_amrfinder.sh <results_dir> <output_file>

RESULTS_DIR=${1:-results}
OUTPUT_FILE=${2:-combined_amrfinder.tsv}

first_file=$(find $RESULTS_DIR -name "*_amrfinder.tsv" | head -1)
echo -e "sample\tplasmid_bin\t$(head -1 $first_file)" > $OUTPUT_FILE

for f in $RESULTS_DIR/*/*_amrfinder.tsv; do
    sample=$(basename $(dirname $f))
    plasmid_bin=$(basename $f _amrfinder.tsv)
    tail -n +2 $f | while IFS= read -r line; do
        echo -e "${sample}\t${plasmid_bin}\t${line}"
    done
done >> $OUTPUT_FILE

echo "Done — written to $OUTPUT_FILE"
echo "Samples included: $(tail -n +2 $OUTPUT_FILE | cut -f1 | sort -u | wc -l)"
echo "Total AMR hits: $(tail -n +2 $OUTPUT_FILE | wc -l)"
