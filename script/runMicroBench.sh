#!/bin/bash
set -u
set -e
AllNodes=`cat script/allnodes`

if [ $# -lt 16 ]
then
    echo "Wrong usage: concurrent, master_num, slave_num, cache_num, master_range, slave_range, cache_range, do_specula, fast_reply, specula_length, pattern, repl_degree, folder"
    exit
else
    concurrent=$1
    master_num=$2
    slave_num=$3
    cache_num=$4
    local_hot_range=$5
    other_master_hot_range=$6
    remote_hot_range=$7
    do_specula=$8
    specula_length=$9
    pattern=${10}
    repl_degree=${11}
    prob_access=${12}
    deter=${13}
    folder=${14}
    Seq=${15}
    Clock=${16}
    if [ $# -eq 17 ]
    then
        HotRate=${17}
    else
        HotRate=10
    fi
    if [ $# -eq 18 ]
    then
        NumKeys=${18}
    else
        NumKeys=10
    fi
    if [ "$do_specula" == true ]; then
	    fast_reply=true
    else
	    fast_reply=false
    fi
fi


#Params: nodes, cookie, num of dcs, num of nodes, if connect dcs, replication or not, branch
Time=`date +'%Y-%m-%d-%H%M%S'`
Folder=$folder/$Time
echo "Folder to make is" $Folder
mkdir $Folder
touch $Folder/$Seq
echo $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${16} $NumKeys $HotRate > $Folder/config
sudo rm -f config
echo ant concurrent $1 >> config 
echo micro concurrent $1 >> config 
echo micro master_num $master_num  >> config
echo micro slave_num $slave_num >> config
echo micro cache_num $cache_num >> config
echo micro master_range 2000000 >> config
echo micro slave_range 2000000 >> config
echo micro cache_range 1000000 >> config
echo micro local_hot_range $local_hot_range >> config
echo micro remote_hot_range $remote_hot_range >> config
echo micro cache_hot_range $remote_hot_range >> config

echo micro local_hot_rate $HotRate >> config
echo micro remote_hot_rate $HotRate >> config
echo micro remote_hot_rate $HotRate >> config

echo micro prob_access $prob_access >> config
echo micro pattern $pattern >> config
#echo micro duration 60 >> config
echo micro total_key $NumKeys >> config
echo micro specula $do_specula >> config
echo micro deter $deter >> config
#ToSleep=$((40000 / ${1}))
NumNodes=`cat ./script/allnodes | wc -l`
MasterToSleep=$((NumNodes*500+10000))
ToSleep=$(((8000 + 800*NumNodes) / ${1}))
echo micro master_to_sleep $MasterToSleep >> config
echo micro to_sleep $ToSleep >> config
#echo load to_sleep 35000 >> config

sudo ./script/copy_to_all.sh ./config ./basho_bench/
sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/config_by_file.sh"

./script/clean_data.sh

#sleep $((MasterToSleep/1000)) && vmstat 2 > $Folder/cpu_info &
#pid=$!
./script/parallel_command.sh "cd basho_bench && sudo mkdir -p tests && sudo ./basho_bench examples/micro.config"

#sudo kill 15 $pid
sudo ./script/gatherThroughput.sh $Folder &
sudo ./script/gatherLatency.sh $Folder &
cp ./tests/current/console.log $Folder
#./script/copyFromAll.sh console.log ./basho_bench/tests/current/ $Folder & 
wait

#./script/getAbortStat.sh `head -1 ./script/allnodes` $Folder 

#timeout 60 ./script/fetchAndParseStat.sh $Folder
#if [ $? -eq 124 ]; then
#    timeout 60 ./script/fetchAndParseStat.sh $Folder
#    if [ $? -eq 124 ]; then
#        timeout 60 ./script/fetchAndParseStat.sh $Folder
#    fi
#fi

#sudo ./script/parallel_command.sh "cd basho_bench && sudo ./script/merge_latency.sh"
#./script/copyFromAll.sh latency_final ./antidote/rel/antidote/ $Folder 
#./script/copyFromAll.sh latency_percv ./antidote/rel/antidote/ $Folder 

