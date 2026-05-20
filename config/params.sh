#!/bin/bash

# pipeline params- edit for your env

THREADS=8
RESULTS_DIR=~/plasmid-triage/results
AMR_DB=/home/ubuntu/miniconda3/envs/plasmid/share/amrfinderplus/data/2023-11-15.1

# Input paath- can be local dir or S3 path
INPUT_PATH=~/plasmid-triage/assemblies

# AMRFinderPlus organism for species-specific point mutations
# leave empty to skip --organism flag
# requires underscores, not spaces ie: Klebsiella_pneumoniae
# run amrfinder --list_organisms to see supported orgs in db version
ORGANISM=""
