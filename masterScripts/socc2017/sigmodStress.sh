#!/bin/bash
set -e

function runNTimes {
    for i in $seq
    do
        if [ $start_ind -gt $skip_len ]; then
        sudo ./script/preciseTime.sh
        ./script/runMicroBench.sh $t $MN $SN $CN $MR $SR $CR $do_specula $len $specula_read $rep $prob_access $deter $folder $start_ind $clock 
        skipped=1
        else
        echo "Skipped..."$start_ind
        fi
        start_ind=$((start_ind+1))
    done
} 

seq="1"
#threads="32 64 96 128 160 192"
#threads="32 64 96 128 160 192 224 256"
#threads="64 128 192 256 320 384 448 512"
#threads="64 128"
#threads="1 2 4 8 16 32 64 128"
#threads="32 64 96 128 160 192 224 256"
#threads="128 64 32 16 8"
#threads="160 80 40 20 10"
threads="10 20 40 80"
contentions="4 2"
start_ind=1
skipped=1
skip_len=0
prob_access=t

rep=5
parts=28
#rep=1
#parts=4

#MBIG=60000
#MSML=6000

#CBIG=15000
#CSML=1500

MBIG=30000
MSML=1000

CBIG=15000
CSML=500

MR=$MBIG 
CR=$CBIG
SR=100000

deter=false

#Test remote read
MN=80
SN=20
CN=0


if [ 1 == 2 ];
then
sudo ./masterScripts/initMachnines.sh 1 benchmark_no_specula_remove_stat
sudo ./script/parallel_command.sh "cd antidote && sudo make rel"

rm -rf ./config
echo micro duration 80 >> config
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

folder="specula_tests/planet"
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

folder="specula_tests/planet"
seq="1 2 3"
# PLANET
clock="old"
specula_read=false
do_specula=true
len=1
length="1"

rm -rf ./config
echo micro duration 80 >> config
echo micro auto_tune false >> config
sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"

sudo ./script/configBeforeRestart.sh 400 $do_specula $len $rep $parts $specula_read
sudo ./script/restartAndConnect.sh

for t in $threads
do
for len in $length
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
done
fi

### Normal specula
seq="1"
do_specula=true
specula_read=true
clock=new
len=0
threads="80"
contentions="2 3"
#sudo ./masterScripts/initMachnines.sh 1 benchmark_precise_remove_stat_forward_rr 
#sudo ./script/parallel_command.sh "cd antidote && sudo make rel"

folder="specula_tests/complementary"
rm -rf ./config
echo micro duration 180 >> config
echo micro auto_tune true >> config
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

threads="80"
contentions="4"
folder="specula_tests/complementary"
rm -rf ./config
echo micro duration 80 >> config
echo micro auto_tune true >> config
echo micro tune_period 1 >> config
echo micro tune_sleep 1 >> config
echo micro centralized true >> config
echo micro max_len 1 >> config
echo micro all_nodes replace >> config
sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"

sudo ./script/configBeforeRestart.sh 500 $do_specula $len $rep $parts $specula_read
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
