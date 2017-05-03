#!/bin/bash
set -e

function runNTimes {
    for i in $seq
    do
        if [ $start_ind -gt $skip_len ]; then
        sudo ./script/preciseTime.sh
        ./script/runMicroBench.sh $t $MN $SN $CN $MR $SR $CR $do_specula $len $specula_read $rep $prob_access $deter $folder $start_ind $clock $HotRate $NumKeys
        skipped=1
        else
        echo "Skipped..."$start_ind
        fi
        start_ind=$((start_ind+1))
    done
} 

seq="1"
HotRate=90
contentions="1 2 3 4 5"
start_ind=1
skipped=1
skip_len=0
prob_access=t

rep=5
parts=28
#rep=3
#parts=8

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
do_specula=true
specula_read=true
clock=new
len=0
threads="40"
sudo ./masterScripts/initMachnines.sh 1 benchmark_precise_remove_stat_forward_rr 
sudo ./script/parallel_command.sh "cd antidote && sudo make rel"

folder="specula_tests/precise_read"
rm -rf ./config
echo micro duration 80 >> config
echo micro auto_tune false >> config
echo micro tune_period 1 >> config
echo micro tune_sleep 1 >> config
echo micro centralized true >> config
echo micro max_len 9 >> config
echo micro all_nodes replace >> config
sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"


sudo ./script/configBeforeRestart.sh 4000 $do_specula $len $rep $parts $specula_read
sudo ./script/restartAndConnect.sh
SR=1000000

for t in $threads
do
    sudo ./script/configBeforeRestart.sh $t $do_specula $len $rep $parts $specula_read
    for cont in $contentions
    do
        if [ $cont == 1 ]; then MR=1000 CR=1000 NumKeys=10
        elif [ $cont == 2 ]; then MR=4000 CR=4000 NumKeys=20
        elif [ $cont == 3 ]; then  MR=25000 CR=25000 NumKeys=40
        elif [ $cont == 4 ]; then  MR=100000 CR=100000 NumKeys=100
        elif [ $cont == 5 ]; then MR=400000 CR=400000 NumKeys=200
        fi
        runNTimes
    done
done

sudo ./masterScripts/initMachnines.sh 1 planet 
sudo ./script/parallel_command.sh "cd antidote && sudo make rel"

rm -rf ./config
echo micro duration 70 >> config
echo micro auto_tune false >> config
sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"

# Baseline
clock="old"
specula_read=true
do_specula=true
len=0
length="0"

sudo ./script/configBeforeRestart.sh 1000 $do_specula $len $rep $parts $specula_read
sudo ./script/restartAndConnect.sh

folder="specula_tests/physical_read"
for t in $threads
do
for len in $length
do
    sudo ./script/configBeforeRestart.sh $t $do_specula $len $rep $parts $specula_read
    for cont in $contentions
    do
        if [ $cont == 1 ]; then MR=1000 CR=1000 NumKeys=10
        elif [ $cont == 2 ]; then MR=4000 CR=4000 NumKeys=20
        elif [ $cont == 3 ]; then  MR=25000 CR=25000 NumKeys=40
        elif [ $cont == 4 ]; then  MR=100000 CR=100000 NumKeys=100
        elif [ $cont == 5 ]; then MR=400000 CR=400000 NumKeys=200
        fi
        runNTimes
    done
done
done
