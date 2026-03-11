# plasmid-triage

Plasmid detection and characterization workflow using MOB-recon and AMRFinderPlus for short-read WGS assemblies. Can be used to triage short-read assemblies for long-read sequencing.

## Background

This workflow detects and characterizes plasmids in bacterial whole genome sequencing (WGS) assemblies generated from Illumina short-read shotgun sequencing. It is based on the plasmid characterization approach described in Sauerborn et al. 2026 (doi: 10.1099/mgen.0.001644), adapted for short-read assemblies.

## Table of Contents

- [Tools](#tools)
- [Input](#input)
- [Installation](#installation)
- [Usage](#usage)
- [How Results Are Combined](#how-mob-recon-and-amrfinderplus-results-are-combined)
- [R Analysis](#r-analysis-to-combine-mob-suite--amrfinderplus-data)
- [Output Files](#output-files)
- [Notes on Short-Read Assemblies](#notes-on-short-read-assemblies)
- [Citations](#citations)

## Tools

- **MOB-suite v3.1.9** — plasmid contig classification, reconstruction and typing
- **AMRFinderPlus v4.0.3** — antimicrobial resistance gene detection
- Database: NCBI Reference Gene Catalog 2024-10-22.1

## Input

Assembled contigs in FASTA format, one file per sample. Edit `config/params.sh` to point to your assemblies directory and results path:

```bash
THREADS=8
RESULTS_DIR=~/plasmid-triage/results
AMR_DB=~/plasmid-triage/amrfinderplus_db
INPUT_PATH=~/plasmid-triage/assemblies
```

## Installation

```bash
# Create conda environment
conda create -n plasmid python=3.9 -y
conda activate plasmid

# Install tools
pip install mob-suite
conda install -c bioconda ncbi-amrfinderplus -y

# Download AMRFinderPlus database
amrfinder_update --database ./amrfinderplus_db
```

### Run with GitHub Codespace

If you don't want to install locally, you can run this repo in a GitHub Codespace:

1. At the root of the repo, click the **Code** dropdown → **Codespaces** tab → click **+**
2. A Codespace will launch with the environment pre-configured
3. To access RStudio within the Codespace: go to the **Ports** tab in the terminal panel, find the port labeled "Rstudio", and click *Open in Browser*

## Usage

Run scripts in this order from your working directory:

```bash
# 1. Classify and reconstruct plasmids
bash scripts/run_mobrecon.sh

# 2. Detect AMR genes on plasmid contigs
bash scripts/run_amrfinder.sh

# 3. Combine outputs across all samples
bash scripts/combine_contig_reports.sh results/ combined_contig_report.tsv
bash scripts/combine_amrfinder.sh results/ combined_amrfinder.tsv
```

## How MOB-recon and AMRFinderPlus Results Are Combined

MOB-recon and AMRFinderPlus answer different but complementary questions:

**MOB-recon** takes your full assembly and classifies every contig as either chromosome or plasmid. It groups plasmid contigs into bins (one bin per reconstructed plasmid) and types each bin for:
- Incompatibility group / replicon type (e.g. IncN, IncF)
- Mobility class (conjugative, mobilizable, non-mobilizable)
- Relaxase and mate-pair formation (MPF) type

**AMRFinderPlus** searches the plasmid contig FASTAs produced by MOB-recon for antimicrobial resistance genes, point mutations, and virulence factors.

**The key linkage** is the contig name — each contig appears in both:
- `contig_report.txt` from MOB-recon (which plasmid bin it belongs to, replicon type, mobility)
- AMRFinderPlus output (which resistance genes it carries)

Joining on contig name lets you answer questions like:
- Which Inc groups are carrying which resistance genes?
- Are carbapenemase genes on conjugative plasmids?
- Which plasmid bins carry multiple resistance genes?

## R Analysis to Combine MOB-suite + AMRFinderPlus Data

Read in the combined outputs and join on contig ID to link AMR hits to plasmid metadata. Note that R replaces spaces and special characters in column names with `.` when reading in tab-delimited files — so for example `Contig id` becomes `Contig.id` and `Gene symbol` becomes `Gene.symbol`.

```r
# Read in the data
contigs <- read.delim("combined_contig_report.tsv", sep="\t", header=TRUE, stringsAsFactors=FALSE)
amr     <- read.delim("combined_amrfinder.tsv", sep="\t", header=TRUE, stringsAsFactors=FALSE)

# Filter to plasmid contigs only
plasmids <- contigs[contigs$molecule_type == "plasmid", ]

# Join AMR hits to plasmid metadata on sample + contig ID
plasmid_amr <- merge(plasmids, amr,
                     by.x = c("sample", "contig_id"),
                     by.y = c("sample", "Contig.id"),
                     all.x = TRUE)

# Which Inc groups carry which resistance classes?
table(plasmid_amr$rep_type, plasmid_amr$Class)

# How many plasmid bins per sample?
aggregate(primary_cluster_id ~ sample, data=plasmids, FUN=function(x) length(unique(x)))

# Total plasmid size per bin (sum contigs within each bin)
aggregate(contig_size ~ sample + primary_cluster_id, data=plasmids, FUN=sum)
```

## Output Files

| File | Description |
|------|-------------|
| `results/{sample}/contig_report.txt` | Per-contig MOB-recon classification for each sample |
| `results/{sample}/plasmid_*.fasta` | Reconstructed plasmid bin sequences |
| `results/{sample}/chromosome.fasta` | Chromosomal contigs |
| `results/{sample}/plasmid_*_amrfinder.tsv` | AMR genes per plasmid bin |
| `combined_contig_report.tsv` | All contig reports merged with sample column |
| `combined_amrfinder.tsv` | All AMR results merged with sample and plasmid bin columns |

### Key columns in combined_contig_report.tsv

| Column | Description |
|--------|-------------|
| `sample` | Sample name |
| `contig_id` | Contig identifier — links to AMRFinderPlus output |
| `molecule_type` | plasmid or chromosome |
| `primary_cluster_id` | Plasmid bin identifier |
| `rep_type` | Replicon/incompatibility group |
| `relaxase_type` | Relaxase classification |
| `predicted_mobility` | conjugative / mobilizable / non-mobilizable |
| `contig_size` | Contig length in bp |

### Key columns in combined_amrfinder.tsv

| Column | Description |
|--------|-------------|
| `sample` | Sample name |
| `plasmid_bin` | Which plasmid bin this hit came from |
| `Gene symbol` | Resistance gene name |
| `Class` | Antibiotic class |
| `Subclass` | Antibiotic subclass |
| `% Coverage of reference sequence` | Gene coverage |
| `% Identity to reference sequence` | Gene identity |

## Notes on Short-Read Assemblies

- Large plasmids (>100kb) will often be fragmented across multiple contigs assigned to the same `primary_cluster_id` — sum `contig_size` within a bin to estimate total plasmid size
- Some plasmid contigs may be unclassified if they lack known replicon or relaxase sequences
- Results should be interpreted at the plasmid bin level rather than individual contig level

## Contributing

Issues and pull requests welcome. Please open an issue first to discuss proposed changes.

## Citations

If you use this workflow please cite the following tools:

**MOB-suite**
Robertson J, Nash JHE. (2018) MOB-suite: software tools for clustering, reconstruction and typing of plasmids from draft assemblies. *Microbial Genomics* 4(8). doi: 10.1099/mgen.0.000206

**AMRFinderPlus**
Feldgarden M, et al. (2021) AMRFinderPlus and the Reference Gene Catalog facilitate examination of the genomic links among antimicrobial resistance, stress response, and virulence. *Scientific Reports* 11:12728. doi: 10.1038/s41598-021-91456-0

Feldgarden M, et al. (2022) Curation of the AMRFinderPlus databases: applications, functionality and impact. *Microbial Genomics* 8:mgen000832. doi: 10.1099/mgen.0.000832

**Reference workflow**
Sauerborn et al. (2026) Resolving plasmid-encoded carbapenem resistance dynamics and reservoirs in a hospital setting through nanopore sequencing. *Microbial Genomics* 12(2). doi: 10.1099/mgen.0.001644

## License

MIT
