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
threads="40"
contentions="1 2 4"
start_ind=1
skipped=1
skip_len=0
prob_access=t

rep=5
parts=28
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
SN=0
CN=0
MNS="99.9 99 95 90 80"

if [ 1 == 2 ]
then
#sudo ./masterScripts/initMachnines.sh 1 benchmark_no_specula_remove_stat
#sudo ./script/parallel_command.sh "cd antidote && sudo make rel"
sudo ./masterScripts/initMachnines.sh 1 planet 
sudo ./script/parallel_command.sh "cd antidote && sudo make rel"

rm -rf ./config
echo micro duration 70 >> config
echo micro auto_tune false >> config
sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"

# Baseline
clock="old"
specula_read=false
do_specula=true
len=0
length="0"

sudo ./script/configBeforeRestart.sh 1000 $do_specula $len $rep $parts $specula_read
sudo ./script/restartAndConnect.sh

folder="specula_tests/remote/clocksirep"
for MN in $MNS
do
for t in $threads
do
for len in $length
do
    sudo ./script/configBeforeRestart.sh $t $do_specula $len $rep $parts $specula_read
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
done
done
fi


seq="1"
do_specula=true
specula_read=true
clock=new
len=0
#sudo ./masterScripts/initMachnines.sh 1 benchmark_precise_remove_stat_forward_rr 
#sudo ./script/parallel_command.sh "cd antidote && sudo make rel"

folder="specula_tests/remote/external"
rm -rf ./config
echo micro duration 120 >> config
echo micro auto_tune true >> config
echo micro tune_period 1 >> config
echo micro tune_sleep 1 >> config
echo micro centralized true >> config
echo micro max_len 9 >> config
echo micro all_nodes replace >> config
sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"


#sudo ./script/configBeforeRestart.sh 4000 $do_specula $len $rep $parts $specula_read
#sudo ./script/restartAndConnect.sh

for MN in $MNS
do
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
        runNTimes
    done
done
done


seq="1"
do_specula=true
specula_read=true
clock=new
len=0

folder="specula_tests/remote/internal"
rm -rf ./config
echo micro duration 120 >> config
echo micro auto_tune true >> config
echo micro tune_period 1 >> config
echo micro tune_sleep 1 >> config
echo micro centralized true >> config
echo micro max_len 1 >> config
echo micro all_nodes replace >> config
sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"

sudo ./script/configBeforeRestart.sh 4000 $do_specula $len $rep $parts $specula_read
sudo ./script/restartAndConnect.sh

for MN in $MNS
do
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
        runNTimes
    done
done
done

