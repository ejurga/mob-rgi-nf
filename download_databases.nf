// Parameters
// Database Locations
params.mobDB = "$workDir/databases/mobDB"
params.card_json = "$workDir/databases"

// Database download controls
params.download_mobDB = false
params.download_card_json = false
params.download_all = false
params.overwrite = false

// Set a flag to donwload the mob database based on input paramters
if ( params.download_all | params.download_mobDB ){
    DL_mob = true 
} else { 
    DL_mob = false
}

// Set a flag to donwload the card json based on input paramters
if ( params.download_all | params.download_card_json ){
    DL_card = true 
} else { 
    DL_card = false
}

// Log message
log.info """ 

    Download Databases
    -------------------
    MOB-suite databases: ${DL_mob}
    CARD json: ${DL_card}

""".stripIndent(true)


process download_CARD_json {
    label "RGI"
    publishDir params.card_json, mode: 'move', overwrite: true

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
    stub: 
    """
    echo Data! > ./card.json
    """

}

process download_MOB_database {
    label "MOB"
    publishDir params.mobDB, mode: 'move', overwrite: true

    input:

    output: 
    path "*"

    script:
    """ 
    mob_init --database_directory '.'
    """

    stub:
    """
    touch status.txt
    """
}

workflow download_CARD_WF {
        
    // If the JSON does not exist, simply download it: 
    if ( !file(params.card_json).exists() ){
        println "Downloading CARD json file, please wait"
        download_CARD_json()
    // But, if it DOES exist:
    } else {
        // Has overwrite flag been set?
        // If YES: download it
        if ( params.overwrite ){
            println "WARNING: file at $params.card_json detected, overwriting!"
            download_CARD_json()
        // But if NO: skip
        } else {
            println(
                "WARNING: file at $params.card_json detected, " + 
                "but overwrite set to $params.overwrite, skipping")
        }
    }
}

workflow download_MOB_WF {
    
    mobDB_dir = file(params.mobDB)
    // If the MOB database does not exist, simply download it: 
    if ( !mobDB_dir.exists() ){
        println "Downloading MOB-suite databases, please wait"
        download_MOB_database()
    // But, if it DOES exist:
    } else {
        // Is the directory empty?
        if ( mobDB_dir.isEmpty() ){
        // If EMPTY: download it:
            println "Downloading MOB-suite databases, please wait"
            download_MOB_database()
        // But if the directory is not empty:
        } else { 
            // Has overwrite flag been set?
            // If YES: download it
            if ( params.overwrite ){
                println (
                    "WARNING: Contents of $params.mobDB detected, " +
                    "overwriting!")
                download_MOB_database()
            // But if NO: skip
            } else {
                println(
                    "WARNING: Contents of $params.mobDB detected " +
                    "but overwrite set to $params.overwrite, skipping" )
            }       
        }
    }
}

workflow {

    // Has user specified that the CARD database be downloaded?
    if ( DL_card ){
        download_CARD_WF()
    }
    // Has use specifed that the MOB database be downloaded?
    if ( DL_mob ){
        download_MOB_WF()
    }

}



