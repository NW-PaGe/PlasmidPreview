#!/bin/bash
# Combine all AMRFinderPlus output files into one TSV
# Usage: bash scripts/combine_amrfinder.sh <results_dir> <output_file>

RESULTS_DIR=${1:-results}
OUTPUT_FILE=${2:-combined_amrfinder.tsv}

first_file=$(find $RESULTS_DIR -name "*_amrfinder.tsv" | head -1)
echo -e "sample\tmolecule_type\tcontig_bin\t$(head -1 $first_file)" > $OUTPUT_FILE

total_hits=0
chromosome_hits=0
plasmid_hits=0
declare -A seen_samples

for f in $RESULTS_DIR/*/*_amrfinder.tsv; do
    sample=$(basename $(dirname $f))
    contig_bin=$(basename $f _amrfinder.tsv)
    seen_samples[$sample]=1

    if [[ "$contig_bin" == chromosome* ]]; then
        molecule_type="chromosome"
    elif [[ "$contig_bin" == plasmid_* ]]; then
        molecule_type="plasmid"
    else
        molecule_type="unknown"
    fi

    while IFS= read -r line; do
        echo -e "${sample}\t${molecule_type}\t${contig_bin}\t${line}"
        ((total_hits++))
        [[ "$molecule_type" == "chromosome" ]] && ((chromosome_hits++))
        [[ "$molecule_type" == "plasmid" ]]    && ((plasmid_hits++))
    done < <(tail -n +2 $f)

done >> $OUTPUT_FILE

echo "Done — written to $OUTPUT_FILE"
echo "Samples included:  ${#seen_samples[@]}"
echo "Total AMR hits:    $total_hits"
echo "Chromosome hits:   $chromosome_hits"
echo "Plasmid hits:      $plasmid_hits"
