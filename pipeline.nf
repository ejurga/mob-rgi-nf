// Pipeline input parameters
params.contigs = ""
// Database parameters
params.mobDB = "./mobDB"
params.download_mobDB = "no"
params.card_json = "./card.json"
params.download_card_json = "no"
params.outDir = "$projectDir/results"


// Log
log.info """\
   Mob-Suite RGI pipeline
   ===================================
   contigs     : ${params.contigs}
   mobDB       : ${params.mobDB}
   Profile     : ${workflow.profile}
   outDir      : ${params.outDir}
   """
   .stripIndent(true)

// Note: what happens if these files are not generated?, e.g., with
// optional flag?


process download_CARD_json {
    label "RGI"

    input: 

    output:
    stdout emit: stdout
    path 'card.json', emit: json


    script:
    """
    echo "Downloading CARD json"
    wget https://card.mcmaster.ca/latest/data
    tar -xvf data ./card.json
    """

}


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

    input:
    tuple val(sample), path(contigs)
    path local_DB

    output:
    tuple val(sample), path("rgi_results.txt"), emit: table
    tuple val(sample), path("rgi_results.json"), emit: json

    script: 
    """

    rgi main \
        --local \
        --input_sequence $contigs \
        --output_file "rgi_results"

    """ 

    stub: 
    """
    touch rgi_results.txt
    touch rgi_results.json
    """
}

process download_MOB_database {
    label "MOB"

    input:

    output: 
    path "mobDB", type: 'dir'

    script:
    """ 
    mob_init --database_directory "./mobDB"
    """

    stub:
    """
    echo Stub command
    mkdir "./mobDB"
    touch mobDB/status.txt
    """
}

process run_mobSuite {
    label "MOB"
    publishDir "${params.outDir}/$sample"

    input: 
    tuple val(sample), path(contigs)
    path DB

    output: 
    tuple val(sample), path("mobSuite/contig_report.txt"), 
      emit: contig_table
    tuple val(sample), path("mobSuite/*.fasta"), 
      emit: fastas
    tuple val(sample), path("mobSuite/mobtyper_results.txt"), 
      emit: typer, optional: true
    tuple val(sample), path("mobSuite/mge.report.txt"), 
      emit: mge, optional: true

    script:
    """

    mob_recon \
      --infile $contigs \
      --outdir mobSuite \
      --num_threads 1 \
      --database_directory $DB

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



workflow {

    // Get the Contigs into a channel
    CONTIGS = Channel
                .fromPath(params.contigs)
                .map { file -> tuple(file.baseName, file) }

    // Download CARD database if specified on the command line.
    if ( params.download_card_json ==~ '[Yy][Ee]{0,1}[Ss]{0,1}' ){
    
        JSON = download_CARD_json()
    
    } else if ( params.download_card_json ==~ '[Nn][Oo]{0,1}' && 
                file(params.card_json).exists() ) {

        JSON = Channel.fromPath(params.card_json)

    } else {
        error "ERROR: CARD json file either not specified or not found"
    }

    // Load RGI database locally.
    LOCAL_DB = load_RGI_database(JSON)

    // Run RGI
    RGI_RESULTS = run_RGI(CONTIGS, LOCAL_DB.out)
    RGI_RESULTS.table.view()

    // Download MOB databases if asked on the command line.
    if ( params.download_mobDB ==~ '[Yy][Ee]{0,1}[Ss]{0,1}' ){
    
        MOB_DB = download_MOB_database()

    } else if ( params.download_mobDB ==~ '[Nn][Oo]{0,1}' &&
                file(params.mobDB).exists() ){

        MOB_DB = Channel.fromPath(params.mobDB)

    } else {
        error "ERROR: MOB-suite Database directory either not specified or not found"
    }

    // Run mob_recon on the contigs using the database.
    MOB_RESULTS = run_mobSuite(CONTIGS, MOB_DB)

    // Create channel with tables to be combined
    TABLES = RGI_RESULTS.table 
                .concat(MOB_RESULTS.contig_table)
                .groupTuple(size: 2)

    // Merge the tables using an included script
    MERGE_TAB = merge_tables(TABLES)

    // This operation concatenates the CSV files, but leaves just one header at 
    // the top 
    MERGE_TAB.out
      .collectFile(
         keepHeader: true, 
         skip: 1, 
         name: 'All_samples.csv', 
         storeDir: params.outDir )
 }

