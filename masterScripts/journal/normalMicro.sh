#!/bin/bash
set -e

function runNTimes {
    for i in $seq
    do
        if [ $start_ind -gt $skip_len ]; then
        sudo ./script/preciseTime.sh
        ./script/runMicroBench.sh $t $MN $SN $CN $MR $SR $CR $do_specula $len $specula_read $rep $prob_access $deter $folder $start_ind $clock $HotRate 10 $con $total_read
        skipped=1
        else
        echo "Skipped..."$start_ind
        fi
        start_ind=$((start_ind+1))
    done
    exit
} 

seq="1"
HotRate=90
start_ind=1
skipped=1
skip_len=0
prob_access=t

rep=1
parts=4
#rep=1
#parts=4

#MBIG=500
#MSML=50

#CBIG=200
#CSML=20

MBIG=30000
MSML=1000
CBIG=15000
CSML=500

MR=$MBIG 
CR=$CBIG
## SR is set to CR anyway, it DOES NOT MATTER!
SR=$CBIG

deter=false

#Test remote read
MN=80
SN=20
CN=0

seq="1"
do_specula=false
specula_read=false
clock=old
len=0
threads="100"
./masterScripts/initMachnines.sh 1 benchmark_no_specula_remove_stat 
./script/parallel_command.sh "cd antidote && sudo make rel"

folder="specula_tests/consistency"
rm -rf ./config
echo micro duration 90 >> config
echo micro auto_tune false >> config
echo micro tune_period 1 >> config
echo micro tune_sleep 1 >> config
echo micro centralized true >> config
echo micro max_len 9 >> config
echo micro all_nodes replace >> config
./script/copy_to_all.sh ./config ./basho_bench/
./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"

./script/configBeforeRestart.sh 4000 $do_specula $len $rep $parts $specula_read
./script/restartAndConnect.sh

len=0
cons="ser"
total_reads="8 4 2 1 0"
threads="120"
contentions="4 1"
for t in $threads
do
    sudo ./script/configBeforeRestart.sh $t $do_specula $len $rep $parts $specula_read
    for cont in $contentions
    do
        if [ $cont == 1 ]; then MR=$MBIG CR=$CBIG
        elif [ $cont == 2 ]; then MR=$MSML CR=$CBIG
        elif [ $cont == 3 ]; then  MR=$MBIG CR=$CSML
        elif [ $cont == 4 ]; then  MR=$MSML CR=$CSML
        fi
        for con in $cons
        do
            for total_read in $total_reads
            do
                runNTimes
            done
        done
    done
done

