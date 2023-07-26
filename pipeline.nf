
// Pipeline input parameters
// params.contigs = "$HOME/Databases/Wright_Culture_Collection/assemblies_by_pathogen/Providencia_stuartii/*.fasta"
params.contigs = '/home/emil/Databases/Wright_Culture_Collection/assemblies_by_pathogen/Citrobacter_youngae/*'
params.mobDB = "$projectDir/databases"
contig_ch = Channel
               .fromPath(params.contigs)
               .map { file -> tuple(file.baseName, file) }

// Log
log.info """\
    Mob-Suite RGI pipeline
    ===================================
    contigs    : ${params.contigs}
    mobDB      : ${params.mobDB}
    Profile    : ${workflow.profile}
    """
    .stripIndent(true)


process just_test {

   input:
   tuple val(sample), path(contigs)

   output:
   stdout

   script:
   """
   echo $sample 
   echo $contigs

   """

}

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


process run_RGI {

   conda 'bioconda::rgi'

   script: 
   """

   echo 'Test'


   """

}

 workflow {
    
    out = run_mobSuite(contig_ch)
    out.view()
 
 }




