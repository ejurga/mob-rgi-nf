// Pipeline input parameters
params.contigs = ""

// Database Locations
params.mobDB = "$workDir/databases/mobDB"
params.card_json = "$workDir/databases/card.json"

// Full RGI or on plasmids only?
params.plasmids_only = false

// Output for results
params.outDir = "$launchDir/results"

// Process parameters
params.num_threads = 1

// Help
params.help = false

def helpMessage() { 

    log.info """
        Usage: 
        nextflow run pipeline.nf \\
            -profile [conda|docker] \\
            --contigs "path/to/contigs/*.fasta"

        Options:
          --contigs         PATH to contigs to run the pipeline on. Multiple 
                            files can be specified using bash globs.
          --mobDB           PATH to the DIRECTORY of the MOB-suite databases
          --card_json       PATH to CARD's card.json file.
          --plasmids_only   Run RGI only on contigs identified as plasmids, thus
                            ignoring any chromosomal AMR determinants.
          --outDir          DIRECTORY to link results to.
          --num_threads     Number of threads to use in downstream processes, 
                            per sample. 
    
    """.stripIndent(true)
}

if (params.help) { 
    helpMessage() 
    exit 0
}


// Log
log.info """\
    Mob-Suite RGI pipeline
    ===================================
    Profile     : ${workflow.profile}
    Contigs     : ${params.contigs}
    mobDB       : ${params.mobDB}
    card.json   : ${params.card_json}
    outDir      : ${params.outDir} 

    PlasmidsOnly? ${params.plasmids_only}
    """
   .stripIndent(true)

// Note: what happens if these files are not generated?, e.g., with
// optional flag?

process load_RGI_database { 
    label "RGI" 

    input:
    path card_json

    output:
    path 'localDB', type: "dir", emit: out

    script:
    """

    rgi load --local --card_json $card_json 

    """

}

process run_RGI { 
    label "RGI"
    publishDir "${params.outDir}/$sample/RGI"
    cpus params.num_threads

    input:
    tuple val(sample), path(contigs)
    path local_DB

    output:
    tuple val(sample), path("rgi_results.txt"), emit: table
    tuple val(sample), path("rgi_results.json"), emit: json

    script: 
    """
    echo "plasmids only? $params.plasmids_only"
    rgi main \
        --local \
        --num_threads ${task.cpus} \
        --input_sequence $contigs \
        --output_file "rgi_results"

    """ 

    stub: 
    """
    touch rgi_results.txt
    touch rgi_results.json
    """
}

process concatenate_plasmid_seqs {

    input:
    tuple val(sample), path(plasmid_contigs)

    output:
    tuple val(sample), path("*.fasta"), emit: contigs

    script:
    """
    cat $plasmid_contigs > ${sample}.fasta

    """
}


process run_mobSuite {
    label "MOB"
    publishDir "${params.outDir}/$sample"
    cpus params.num_threads

    input: 
    tuple val(sample), path(contigs)

    output: 
    tuple val(sample), path("mobSuite/contig_report.txt"), 
      emit: contig_table
    tuple val(sample), path("mobSuite/plasmid*.fasta"), 
      emit: plasmid_fastas, optional: true
    tuple val(sample), path("mobSuite/mobtyper_results.txt"), 
      emit: typer, optional: true
    tuple val(sample), path("mobSuite/mge.report.txt"), 
      emit: mge, optional: true

    script:
    """

    mob_recon \
      --infile $contigs \
      --outdir mobSuite \
      --num_threads ${task.cpus} \
      --database_directory $params.mobDB \
      --force 

    """
    stub: 
    """
    mkdir mobSuite
    touch mobSuite/contig_report.txt
    touch mobSuite/chromosome.fasta
    """
}

process merge_tables {
    label "RGI"
    publishDir "${params.outDir}/$sample/Merge"
    cache false

    input:
    tuple val(sample), path(tables)

    output:
    path('merged_tables.csv'), emit: out

    script: 
    """
    python $projectDir/bin/merge.py ${tables[0]} ${tables[1]}

    """
}

process create_report {
    label "RGI"
    publishDir "${params.outDir}"
    cache false

    input: 
    path(table)

    output: 
    path('report.html'), emit: out

    script: 
    """
    #!/usr/bin/env Rscript 

    rmarkdown::render(
        input = "${projectDir}/bin/generate_report.rmd",
        params = list(data = "${table}"),
        output_file = "report.html",
        knit_root_dir = getwd(),
        output_dir = getwd()
        )
    """
}

workflow {

    // Get the Contigs into a channel
    CONTIGS = Channel
                .fromPath(params.contigs)
                .map { file -> tuple(file.baseName, file) }

    // Run mob_recon on the contigs.
    MOB_RESULTS = run_mobSuite(CONTIGS)
    
    // Get the CARD Json
    JSON = Channel.fromPath(params.card_json)
    // Load RGI database locally.
    LOCAL_DB = load_RGI_database(JSON)

    // Run RGI
    // Does the user want to run RGI on plasmids only?
    if ( params.plasmids_only ){
        // Merge plasmid seqs into a single file
        PLASMID_CONTIGS = concatenate_plasmid_seqs(MOB_RESULTS.plasmid_fastas)
        // Run RGI on the plasmid contigs only
        RGI_RESULTS = run_RGI(  PLASMID_CONTIGS.contigs,
                                LOCAL_DB.out.collect()  )
    } else { 
        // Otherwise, just run RGI on the full sample set
        RGI_RESULTS = run_RGI(CONTIGS, LOCAL_DB.out.collect())
    }

    // Create channel with tables to be combined
    TABLES = RGI_RESULTS.table 
                .concat(MOB_RESULTS.contig_table)
                .groupTuple(size: 2)

    // Merge the tables using an included script
    MERGE_TAB = merge_tables(TABLES)

    // This operation concatenates the CSV files, but leaves just one header at 
    // the top 
    CAT_TAB = MERGE_TAB.out
                .collectFile(keepHeader: true, 
                             skip: 1, 
                             name: 'All_samples.csv', 
                             storeDir: params.outDir )

    // Create report
    create_report(CAT_TAB)
 }

