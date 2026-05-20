# plasmid-triage

This is a filtering/hypothesis-generating workflow for plasmid detection and characterization. It uses MOB-recon and AMRFinderPlus on short-read WGS assemblies. 

This workflow can be used to triage short-read contig-level assemblies for long-read sequencing, which can then determine plasmid content of bacterial isolate sequences.

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

Assembled contigs in FASTA format, one file per sample inside a folder named assemblies

## Params

The scripts in this repo reference the paths listed in the file `config/params.sh`. Edit `config/params.sh` to point to your assemblies directory and results path (Note you may need to create directories for your assemblies and results (or use a S3 URI for assemblies):

```bash
THREADS=8
RESULTS_DIR=~/plasmid-triage/results
AMR_DB=~/plasmid-triage/amrfinderplus_db
INPUT_PATH=~/plasmid-triage/assemblies
```

## Installation


Installation using mamba
```
conda create -n mamba-env -c conda-forge mamba -y
conda activate mamba-env

mamba create -n plasmid -c conda-forge -c bioconda python=3.9 ncbi-amrfinderplus -y
conda activate plasmid

# MOB-suite is not available on conda and must be installed via pip. 
#Dependencies must be installed separately via conda **before** running `mob_init`:

conda install -c bioconda -c conda-forge mash blast muscle
pip install mob-suite
mob_init --database_directory ~/mobsuite_db

# Download AMRFinderPlus database
amrfinder_update --database ./amrfinderplus_db
```

## AMRFinderPlus Database Setup

After creating and activating the conda environment, the bundled database may be outdated. 
Always update the database before running:
```bash
cd ~
mkdir -p ~/tmp
export TMPDIR=~/tmp
amrfinder --update
```

Verify the software and database versions:
```bash
amrfinder --database_version
```

As of this writing, the expected versions are:
- **Software:** 4.2.7
- **Database:** 2026-03-24.1

> **Note:** `amrfinder --update` must be run from `~` (not a subdirectory that may not persist),
> and `TMPDIR` must point to a directory with sufficient space. On EC2 instances, `/tmp` is often
> too small to build the BLAST index — redirecting to `~/tmp` resolves this.

## Usage

Run scripts in this order from your working directory (plasmid-triage):  

**note** this runs each sample sequentially and will take several minutes per sample for mob-recon
**TODO** parallelize workflow and/or move to sequera or aws batch to make hundreds of samples take the time it takes to run one.  

```bash
# 1. Classify and reconstruct plasmids
bash scripts/run_mobrecon.sh

# 2. Detect AMR genes on all contigs (plasmid and chromosomal-as determined by mobrecon)
bash scripts/run_amrfinder.sh

# 3. Combine outputs across all samples
bash scripts/combine_contig_reports.sh results/ combined_contig_report.tsv
bash scripts/combine_amrfinder.sh results/ combined_amrfinder.tsv
```
### Species-specific AMR detection (optional)
AMRfinderPlus can apply species-specific point mutation information when you provide the species name for some species.  
To evaluate if a species is supported run:  

```bash
amrfinder --list_organisms
```
either leave organism in params.sh blank, or insert species of interest per formatting above in --list_organisms ie Klebsiella_pneumoniae  
**Note:** A single organism value is applied to all samples in the run, for mixed species runs, run separately. 

If the plasmid/chromosome for a given plasmid result is ambiguous, treat  the contig as a possible plasmid sequence for filtering-  this workflow is a screen, and we want to increase the chances of detecting plasmids at the expense of potentially having some false positives- we do not want to have false negative plasmid calls (ie miss samples that should really go to long-read sequencing for more definitive plasmid detection analysis)  

## How MOB-recon and AMRFinderPlus Results Are Combined

MOB-recon and AMRFinderPlus answer different but complementary questions:

**MOB-recon** takes your full assembly and classifies every contig as either chromosome or plasmid. It groups plasmid contigs into bins (one bin per reconstructed plasmid) and types each bin for:
- Incompatibility group / replicon type (e.g. IncN, IncF)
- Mobility class (conjugative, mobilizable, non-mobilizable)
- Relaxase and mate-pair formation (MPF) type

**AMRFinderPlus** searches the plasmid contig FASTAs produced by MOB-recon for antimicrobial resistance genes, point mutations, and virulence factors.

**The key linkage** is the contig bin — each bin appears in both:
- `contig_report.txt` from MOB-recon (which plasmid bin it belongs to, replicon type, mobility- called: primary_cluster_id)
- AMRFinderPlus output (which resistance genes it carries- called: plasmid_bin)

Joining on plasmid bins lets you filter (triage) short read shotgun genome sequences for samples where the following questions may be relevant :
- Which Inc groups are carrying which resistance genes?
- Are carbapenemase genes on conjugative plasmids?
- Which plasmid bins carry multiple resistance genes?

**Note:** these questions can only definitively be addressed with long-read data

## R Analysis to Combine MOB-suite + AMRFinderPlus Data

Read in the combined outputs and join on contig ID to link AMR hits to plasmid metadata using the Rmd notebook in the notebooks section.  


## Output Files

| File | Description |
|------|-------------|
| `results/{sample}/contig_report.txt` | Per-contig MOB-recon classification for each sample |
| `results/{sample}/plasmid_*.fasta` | Reconstructed plasmid bin sequences |
| `results/{sample}/chromosome.fasta` | Chromosomal contigs |
| `results/{sample}/plasmid_*_amrfinder.tsv` | AMR genes per plasmid bin |
| `results/{sample}/chromosome_amrfinder.tsv` | AMR genes on chromosomal contigs |
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
| `molecule_type` | plasmid or chromosome |
| `contig_bin` | Which plasmid bin or chromosome this hit came from |
| `Gene symbol` | Resistance gene name |
| `Class` | Antibiotic class |
| `Subclass` | Antibiotic subclass |
| `% Coverage of reference sequence` | Gene coverage |
| `% Identity to reference sequence` | Gene identity |

## Notes on Short-Read Assemblies

-this workflow may misclassify chromosomal sequences as plasmids- this can happen with multireplicon and large plasmids.  This could manifest as no plasmids detected, but mob_recon results multiple contigs marked as chromosomes-ie plasmids may be present but not detected by mob_recon.  
- Large plasmids (>100kb) will often be fragmented across multiple contigs assigned to the same `primary_cluster_id` — sum `contig_size` within a bin to estimate total plasmid size
- Some plasmid contigs may be unclassified if they lack known replicon or relaxase sequences
- Results should be interpreted at the plasmid bin level rather than individual contig level  

## Contributing



## Citations

If you use this workflow please cite the following tools:

**MOB-suite**
Robertson J, Nash JHE. (2018) MOB-suite: software tools for clustering, reconstruction and typing of plasmids from draft assemblies. *Microbial Genomics* 4(8). doi: 10.1099/mgen.0.000206

**AMRFinderPlus**
Feldgarden M, et al. (2021) AMRFinderPlus and the Reference Gene Catalog facilitate examination of the genomic links among antimicrobial resistance, stress response, and virulence. *Scientific Reports* 11:12728. doi: 10.1038/s41598-021-91456-0

Feldgarden M, et al. (2022) Curation of the AMRFinderPlus databases: applications, functionality and impact. *Microbial Genomics* 8:mgen000832. doi: 10.1099/mgen.0.000832

**Reference workflow inspiration**
Sauerborn et al. (2026) Resolving plasmid-encoded carbapenem resistance dynamics and reservoirs in a hospital setting through nanopore sequencing. *Microbial Genomics* 12(2). doi: 10.1099/mgen.0.001644

## License


