
// Pipeline input parameters

params.contigs = "$HOME/Databases/Wright_Culture_Collection/assemblies_by_pathogen/Providencia_stuartii/*.fasta"
params.mobDB = "$HOME"
contig_ch = Channel.fromPath(params.contigs)




process run_mobSuite {

conda 'bioconda::mob_suite'

input: 
path contigs

output: 
stdout

script:
"""
grep -c "^>" $contigs

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

   println "$params.contigs"
   seqs_ch = run_mobSuite(contig_ch)
   seqs_ch.view()
   run_RGI()

}



