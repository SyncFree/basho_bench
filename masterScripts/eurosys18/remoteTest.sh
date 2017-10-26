#!/bin/bash
set -e

function runNTimes {
    for i in $seq
    do
        if [ $start_ind -gt $skip_len ]; then
        sudo ./script/preciseTime.sh
        ./script/runMicroBench.sh $t $MN $SN $CN $MR $SR $CR $do_specula $len $specula_read $rep $prob_access $deter $folder $start_ind $clock $HotRate
        skipped=1
        else
        echo "Skipped..."$start_ind
        fi
        start_ind=$((start_ind+1))
    done
} 

seq="1"
HotRate=90
threads="10 20 40 80"
contentions="4 2"
start_ind=1
skipped=1
skip_len=0
prob_access=t

rep=1
parts=4

MBIG=1000
MSML=100

CBIG=500
CSML=50

MR=$MBIG 
CR=$CBIG
SR=100000

deter=false

#Test remote read
MN=80
SN=20
CN=0


### Normal specula
seq="1"
do_specula=true
specula_read=true
clock=new
len=8
threads="40"
contentions="1 2 4"
#sudo ./masterScripts/initMachnines.sh 1 benchmark_precise_remove_stat_forward_rr 
#sudo ./script/parallel_command.sh "cd antidote && sudo make rel"

folder="specula_tests/specula"
rm -rf ./config
echo micro duration 60 >> config
echo micro auto_tune false >> config
echo micro tune_period 2 >> config
echo micro tune_sleep 1 >> config
echo micro centralized true >> config
echo micro max_len 9 >> config
echo micro all_nodes replace >> config
sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"

sudo ./script/configBeforeRestart.sh 4000 $do_specula $len $rep $parts $specula_read
sudo ./script/restartAndConnect.sh

for t in $threads
do
    #sudo ./script/configBeforeRestart.sh $t $do_specula $len $rep $parts $specula_read
    for cont in $contentions
    do
        if [ $cont == 1 ]; then MR=$MBIG CR=$CBIG
        elif [ $cont == 2 ]; then MR=$MSML CR=$CBIG
        elif [ $cont == 3 ]; then  MR=$MBIG CR=$CSML
        elif [ $cont == 4 ]; then  MR=$MSML CR=$CSML
        fi
        runNTimes
    done
done
exit

MN=80
SN=20
CN=0
for t in $threads
do
    #sudo ./script/configBeforeRestart.sh $t $do_specula $len $rep $parts $specula_read
    for cont in $contentions
    do
        if [ $cont == 1 ]; then MR=$MBIG CR=$CBIG
        elif [ $cont == 2 ]; then MR=$MSML CR=$CBIG
        elif [ $cont == 3 ]; then  MR=$MBIG CR=$CSML
        elif [ $cont == 4 ]; then  MR=$MSML CR=$CSML
        fi
        runNTimes
    done
done
