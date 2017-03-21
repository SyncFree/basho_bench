#!/usr/bin/env bash
# This script assumes that there are tar files sent by the workers
# in a tests/fmk-bench-date-time folder.
# It merges all those results into a single one.
# It is called by the master-runBenchmarkStarter.sh script

# run like : BenchResultsDirectory=$dir master-mergeResults.sh
# INPUT:
# 1) BenchResultsDirectory, the directory where the worker result tar files are stored.

# This is only necessary when running on OS X, erlang 19
# might be removed, but won't harm otherwise...

export KEY_SPACES=( 10000000 1000000 100000 10000 )
export ROUND_NUMBER=( 10 )
export READ_NUMBER=( 100 100 100 )
export UPDATE_NUMBER=( 2 10 100 )


PATH="$PATH:/opt/local/lib/erlang/erts-8.1/bin/"
chmod +x ~/basho_bench/script/g5k/*
chmod +x ~/antidote/bin/*

########################################################
    # check we got a correct directory with tar files
#########################################################
if [ -z "$BenchResultsDirectory" ]
  then
    BenchResultsDirectory=$(pwd)
fi
echo "---### MASTER: STARTING to merge Results in ${BenchResultsDirectory}"

# Define the number of bench nodes from the number of files in the directory
# NOTE: this assumes that the master-runBenchmarkStarter.sh script has already verified
# that all workers have sent their results to the target dir.

cd $BenchResultsDirectory
#Numfiles=$(eval "\ls -afq | wc -l")
# substract 2 as the previous command counts the . and .. directories
#NumBenchNodes=$((Numfiles-2))

########################################################
    # Untar files into a dir with the tarfile name
#########################################################
for File in ./*.tar ; do
        echo "---### MASTER: Untaring file ${File} into directory ${FileWithoutExtension}"
        FileWithoutExtension="${File%.*}"
        mkdir $FileWithoutExtension
        tar -C $FileWithoutExtension -xf "$File"
#        rm $File
done

for keyspace in "${KEY_SPACES[@]}"; do
    export KEYSPACE=${keyspace}
    for rounds in "${ROUND_NUMBER[@]}"; do
      export ROUNDS=${rounds}
      re=0
      for reads in "${READ_NUMBER[@]}"; do
        export UPDATES=${UPDATE_NUMBER[re]}
        export READS=${reads}


        # create the summary result
            summaryDir="basho_bench_summary-$KEYSPACE-$ROUNDS-$READS-$UPDATES"
            mkdir -p $summaryDir
            echo "---### MASTER: created summary directory : $summaryDir"



            ########################################################
                # Merge Summary Files
            ########################################################
#            get all directories that contain results for a given workload $KEYSPACE-$ROUNDS-$READS-$UPDATES
            SummaryFile=summary.csv
            TxnLatencyFile=txn_latencies.csv
            SummaryFiles=""
            TxnLatencyFiles=""
            Dirs=( $(find . -type d -name "test*-$KEYSPACE-$ROUNDS-$READS-$UPDATES") )
            for Dir in  ${Dirs[@]}; do
                    echo "---### MASTER: Collecting all ${SummaryFile} in $Dir"
                    thisSummaryFile=( $(find "$Dir" -type f -name "$SummaryFile") )
                    SummaryFiles="$thisSummaryFile $SummaryFiles"

                   ########################################################
                    # get all the latency files (that end with _latencies.csv") in the results directory
                    ########################################################
                        echo "---### MASTER: Collecting all ${TxnLatencyFile} in $Dir"
                    thisLatencyFile=( $(find "$Dir" -type f -name "$TxnLatencyFile") )
                    TxnLatencyFiles="$thisLatencyFile $TxnLatencyFiles"
                    cd $BenchResultsDirectory
            done

            echo "---### MASTER: all Summary files are: ${SummaryFiles}"
            echo "---### MASTER: all Latency files are: ${TxnLatencyFiles}"
                    ########################################################
                    # Now use this magic command to merge them into a file into the summary directory
                    ########################################################
                    echo "---### MASTER: Merging all those files into summaryDir/${SummaryFile}"
                    awk -f ~/basho_bench/script/mergeResultsSummary.awk $SummaryFiles > $BenchResultsDirectory/$summaryDir/${SummaryFile}
                    echo "---### MASTER: done"


                    ########################################################
                    # Now use this magic command to merge them into a file into the summary directory
                    ########################################################
                        echo "---### MASTER: Merging all those files into summary/${TxnLatencyFile}"
                        awk -f ~/basho_bench/script/mergeResults.awk $TxnLatencyFiles > $BenchResultsDirectory/$summaryDir/${TxnLatencyFile}
                        echo "---### MASTER: done"
                         echo "---### MASTER: creating pretty summary.png"
                        Rscript --vanilla ~/basho_bench/priv/summary.r -i "$BenchResultsDirectory/$summaryDir/"
        re=$((re+1))
      done
    done
  done