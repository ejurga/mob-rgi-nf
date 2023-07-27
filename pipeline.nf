
// Pipeline input parameters
// params.contigs = "$HOME/Databases/Wright_Culture_Collection/assemblies_by_pathogen/Providencia_stuartii/*.fasta"
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

process run_mobSuite {

   input: 
   tuple val(sample), path(contigs)

   output: 
   tuple val(sample), path('results',  type: 'dir')

   script:
   """

   mob_recon \
      --infile $contigs \
      --outdir results \
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

    input:
    tuple val(sample), path(contigs)

    output:
    tuple val(sample), path("rgi_results.*")

    script: 
    """

    rgi main \
        --input_sequence $contigs \
        --output_file "rgi_results"
   
    """
}

 workflow {
  
    load_RGI_database(card_json_ch)
    rgi_ch = run_RGI(contig_ch)
    mob_ch = run_mobSuite(contig_ch)

    rgi_ch.view()
    mob_ch.view()
 
 }




