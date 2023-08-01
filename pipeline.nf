// Pipeline input parameters
params.contigs = ""
params.mobDB = "$projectDir/databases"
params.card_json = ""
contig_ch = Channel
               .fromPath(params.contigs)
               .map { file -> tuple(file.baseName, file) }
card_json_ch = Channel.fromPath(params.card_json)


// Log
log.info """\
   Mob-Suite RGI pipeline
   ===================================
   contigs    : ${params.contigs}
   mobDB      : ${params.mobDB}
   Profile    : ${workflow.profile}
   """
   .stripIndent(true)

// Note: what happens if these files are not generated?, e.g., with 
// optional flag?
process run_mobSuite {
   publishDir "./results/$sample"

   input: 
   tuple val(sample), path(contigs)

   output: 
   tuple val(sample), path("mobSuite/contig_report.txt"), 
      emit: contig
   tuple val(sample), path("mobSuite/*.fasta"), 
      emit: fastas
   tuple val(sample), path("mobSuite/mobtyper_results.txt"), 
      emit: typer
   tuple val(sample), path("mobSuite/mge.report.txt"), 
      emit: mge

   script:
   """

   mob_recon \
      --infile $contigs \
      --outdir mobSuite \
      --num_threads 1 \
      --database_directory $params.mobDB

   """
}

process load_RGI_database { 
   label "RGI"

   input: 
   path(card_json)

   output:
   stdout

   script:
   """

   rgi load --card_json $card_json 


   """

}

process run_RGI { 
   label "RGI"
   publishDir "./results/$sample/RGI"

   input:
   tuple val(sample), path(contigs)

   output:
   tuple val(sample), path("rgi_results.txt"), emit: table
   tuple val(sample), path("rgi_results.json"), emit: json

   script: 
   """

   rgi main \
      --input_sequence $contigs \
      --output_file "rgi_results"
   
    """ 
}

process merge_tables {
    label "RGI"
    publishDir "./results/$sample/Merge"

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
 
    // Run RGI
    load_RGI_database(card_json_ch)
    rgi = run_RGI(contig_ch)


    // Run MobTyper
    mob = run_mobSuite(contig_ch)

    // Create channel with tables to be combined
    list_ch = rgi.table
                .concat(mob.contig)
                .groupTuple(size: 2)

    // Merge the tables using an included script
    merge_tables(list_ch)
        
     
 }




