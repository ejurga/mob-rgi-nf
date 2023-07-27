
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
   
    """ }

 workflow {
 
   // Run RGI
   load_RGI_database(card_json_ch)
   rgi = run_RGI(contig_ch)
   rgi.table.view()
   rgi.json.view()


   // Run MobTyper
   mob = run_mobSuite(contig_ch)
   mob.contig.view()
   mob.fastas.view()
   mob.typer.view() 
   mob.mge.view()


     
 }




