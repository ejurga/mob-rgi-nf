# MOB-RGI-NF

A NextFlow pipeline to identify antimicrobial genes and plasmids from genomic
sequence data


## Introduction

Plasmids are mobile genetic elements, and are often significant carriers of
antimicrobial resistance genes. MOB-suite is a tool that is used to
reconstruct and type plasmid sequences from whole genome sequence data. However,
it does not identify AMR elements on identified plasmid sequences. The
Resistance Gene Identifier (RGI) is a suite of tools that uses the Comprehensive
Antimicrobial Database (CARD) to identify AMR determinants from whole genome
sequence data. This pipeline serves as the union of these two tools, and
therefore allows for the identification of AMR determinants present on mobile
genetic elements from a given set of whole genome sequence data.

## Overview

The nextflow script `download_databases.nf` is used to download the databases
used by RGI and MOB-suite (if needed).

The nextflow script `pipeline.nf` runs both tools on a provided set of
sequences. Both RGI and MOB-suite output their results in the form of tabular
files. These results are merged, associating each detected AMR determinant with
MOB-suite's results. This enables the user to identify if the AMR determinants
are present on the chromosome, or on a plasmid. If multiple samples are passed
to the program, the results will be collated into a single table.


## Installation

Dependencies:

* NextFlow
* If using conda profile: 
    - Conda
    - Mamba
* If using docker profile: 
    - Docker

## Usage

Clone this pipeline into a working directory. 

### Download databases

Both MOB-suite and RGI require databases to be downloaded in order to run the
tools. MOB-RGI-NF provides a pipeline to download the databases if the user does
not already have them. You may specify `--download_mobDB` to download the
MOB-suite databases, `--download_card_json` to download the CARD json file, or
`--download_all` to download both.

```bash
nextflow run download_databases.nf \
    -profile [conda|docker] \
    --download_all
```

By default, this command will download both databases into a `databases` folder
in nextflow's `work` directory. This keeps the databases out of the way and
prevents them from being deleted when nextflow runs are cleaned during analyses.

However, the user can specify their own locations instead. In this case, make
sure to also specify the location of these databases when running the analysis
pipeline.

```bash
nextflow run download_databases.nf \
    -profile [conda|docker] \
    --download_all \
    --mobDB "/path/to/mobDB/directory" \
    --card_json "/path/to/card/directory"
```

By default, MOB-RGI-NF will not overwrite the databases if
it detects that they are already installed at the given path; set `--overwrite`
to overwrite the existing databases if needed.

### Detect AMR determinants and plasmids

#### Basic Usage

Use the script `pipeline.nf` to run mobSuite and RGI. The input should be
assembled contigs. Use a bash glob to designate multiple sequences to be run by
the pipeline. Note that the:wq file names will be used to designate sample ID.

Make sure to select a run profile, depending on the container
you want to use. Currently conda (using mamba) and docker are supported. The
pipeline will handle downloading and initializing the containers. Therefore, the
very first run will take some time as the proper containers are downloaded.

```bash
nextflow run pipeline.nf \
    -profile [conda|docker] \
    --contigs "dir/to/sequences/*.fasta"
```

This command assumes that the databases have first been downloaded into the
default directory by the `download_databases.nf` pipeline. Otherwise, specify
the location of the databases. Use the option `--mobDB` to specify the path to
the parent directory of the MOB-suite databases, and `--cardDB` to specify the
path to the card.json file

The results will be collected in the directory `results` in the project
directory by default. This can be changed with the option `--outDir`.

#### Detecting only AMR on plasmids

By default, MOB-RGI-NF will run RGI on all the contigs in a provided fasta file.
This means it will detect AMR determinants present on the chromosome, as well as
those on plasmids. Since RGI and MOB-suite can be run separately, the pipeline
will use both tools in parallel, and merge the results at the end. If you are
only interested in AMR determinants on plasmids, the option `--plasmids_only`
can be supplied. This will run RGI only on contigs determined by MOB-suite to be
from plasmids, and will significantly decrease the time it takes to run RGI.
However, it means that RGI cannot be run parallel to MOB-suite, and so the
actual time to completion of the pipeline may not actually be shorter, unless
many samples are being processed at the same time.

## Visuals
Depending on what you are making, it can be a good idea to include screenshots or even a video (you'll frequently see GIFs rather than actual videos). Tools like ttygif can help, but check out Asciinema for a more sophisticated method.

## Support
Tell people where they can go to for help. It can be any combination of an issue tracker, a chat room, an email address, etc.

## Authors and acknowledgment
Show your appreciation to those who have contributed to the project.

## License
For open source projects, say how it is licensed.

