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
export READ_NUMBER=( 100 100 100)
export UPDATE_NUMBER=( 2 10  100)


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
stalenessTarFiles=( $(find . -type f -name "*StalenessResults.tar") )
for File in ${stalenessTarFiles[@]} ; do
        FileWithoutExtension="${File%.*}"
        echo "---### MASTER: Untaring file ${File} into directory ${FileWithoutExtension}"
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

            StaleDirectories=$(find . -type d -name "Stale-$KEYSPACE-$ROUNDS-$READS-$UPDATES")
        # create the summary result
            summaryDir="staleness_summary-$KEYSPACE-$ROUNDS-$READS-$UPDATES"
            mkdir -p $summaryDir
            echo "---### MASTER: created summary directory : $summaryDir"


            echo "~/antidote/bin/physics_staleness/process_staleness.erl "\"Stale-$KEYSPACE-$ROUNDS-$READS-$UPDATES ${StaleDirectories[@]}\"""
            ~/antidote/bin/physics_staleness/process_staleness.erl "Stale-$KEYSPACE-$ROUNDS-$READS-$UPDATES ${StaleDirectories[@]}"






        re=$((re+1))
      done
    done
  done