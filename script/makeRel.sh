#!/bin/bash

cd /root/basho_bench1/basho_bench/

AllNodes=`cat script/allnodes`
Command1="pkill beam"
Command3="cd ./antidote/ && make relnocert"

./script/parallel_command.sh "$AllNodes" "$Command1"
./script/parallel_command.sh "$AllNodes" "$Command3"
