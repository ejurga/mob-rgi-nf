// Pipeline input parameters
params.contigs = ""

// Database Locations
params.mobDB = "$workDir/databases/mobDB"
params.card_json = "$workDir/databases/cardDB"

// Output for results
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
    
    // Get the CARD Json
    JSON = Channel.fromPath(params.card_json)
    // Load RGI database locally.
    LOCAL_DB = load_RGI_database(JSON)
    // Run RGI
    RGI_RESULTS = run_RGI(CONTIGS, LOCAL_DB.out)
    RGI_RESULTS.table.view()


    // Get the MOB datbase path.     
    MOB_DB = Channel.fromPath(params.mobDB)
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

