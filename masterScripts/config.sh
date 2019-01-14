#!/bin/bash
set -e

cd basho_bench
AllNodes=`cat ./script/allnodes` 


#Change config for basho_bench
ReplList="["
AntNodeArray=()
I=0
for Node in $AllNodes
do
    CurrentNode="'antidote@"$Node"'"
    AntNodeArray[$I]=$CurrentNode
    I=$((I+1))
done
Ip=`GET http://169.254.169.254/2014-11-05/meta-data/public-ipv4`
LocalIp=`GET http://169.254.169.254/2014-11-05/meta-data/local-ipv4`
echo $Ip
echo $LocalIp
CurrentNode="'antidote@"$Ip"'"
LoadNode="['load@"$Ip"',longnames]"
BenchNode="['tpcc@"$Ip"',longnames]"
MicroNode="['micro@"$Ip"',longnames]"
RubisNode="['rubis@"$Ip"',longnames]"
echo $CurrentNode
echo "$CurrentNode"
sudo sed -i -e "s/{antidote_pb_ips.*/{antidote_pb_ips, [$CurrentNode]}./" examples/tpcc.config 
sudo sed -i -e "s/{antidote_pb_ips.*/{antidote_pb_ips, [$CurrentNode]}./" examples/micro.config 
sudo sed -i -e "s/{antidote_pb_ips.*/{antidote_pb_ips, [$CurrentNode]}./" examples/rubis.config 
sudo sed -i -e "s/{antidote_pb_ips.*/{antidote_pb_ips, [$CurrentNode]}./" examples/load.config 
sudo sed -i -e 's/{code_paths.*/{code_paths, [\x22\x2E\x2E\x2Fantidote\x2Febin\x22]}./' examples/tpcc.config 
sudo sed -i -e 's/{code_paths.*/{code_paths, [\x22\x2E\x2E\x2Fantidote\x2Febin\x22]}./' examples/micro.config 
sudo sed -i -e 's/{code_paths.*/{code_paths, [\x22\x2E\x2E\x2Fantidote\x2Febin\x22]}./' examples/rubis.config 
sudo sed -i -e 's/{code_paths.*/{code_paths, [\x22\x2E\x2E\x2Fantidote\x2Febin\x22]}./' examples/load.config 
sudo sed -i -e "s/{web_ip.*/{web_ip, \x22$Ip\x22}./" /home/ubuntu/antidote/rel/vars.config 
sudo sed -i -e "s/{pb_ip.*/{pb_ip, \x22$LocalIp\x22}./" /home/ubuntu/antidote/rel/vars.config 
sudo sed -i -e "s/{node.*/{node, \x22antidote@$Ip\x22}./" /home/ubuntu/antidote/rel/vars.config 

./localScripts/changeConfig.sh examples/load.config antidote_mynode "$LoadNode"
./localScripts/changeConfig.sh examples/tpcc.config antidote_mynode "$BenchNode"
./localScripts/changeConfig.sh examples/micro.config antidote_mynode "$MicroNode"
./localScripts/changeConfig.sh examples/rubis.config antidote_mynode "$RubisNode"

I=0
Length=${#AntNodeArray[@]}
echo $Length
for Node in $AllNodes
do
    CurrentNode="'antidote@"$Node"'"
    NextI=$(((I+1) % Length))
    DNextI=$(((I+2) % Length))
    ThirdI=$(((I+3) % Length))
    if [ $I -ne 0 ]; then
        ReplList=$ReplList",{"$CurrentNode",["${AntNodeArray[$NextI]}","${AntNodeArray[$DNextI]}","${AntNodeArray[$ThirdI]}"]}"
    else
        ReplList=$ReplList"{"$CurrentNode",["${AntNodeArray[$NextI]}","${AntNodeArray[$DNextI]}","${AntNodeArray[$ThirdI]}"]}"
    fi
    #if [ $I -ne 0 ]; then
    #    ReplList=$ReplList",{"$CurrentNode",["${AntNodeArray[$NextI]}","${AntNodeArray[$DNextI]}","${AntNodeArray[$ThirdI]}"]}"
    #else
    #    ReplList=$ReplList"{"$CurrentNode",["${AntNodeArray[$NextI]}","${AntNodeArray[$DNextI]}","${AntNodeArray[$ThirdI]}"]}"
    #fi
    I=$((I+1))
done
ReplList=$ReplList"]"
echo "$ReplList"
./localScripts/changeConfig.sh /home/ubuntu/antidote/rel/antidote/antidote.config to_repl "$ReplList"
./localScripts/changeConfig.sh /home/ubuntu/antidote/rel/antidote/antidote.config do_repl true 
./localScripts/changeConfig.sh /home/ubuntu/antidote/rel/antidote/etc/app.config pb_ip "\x22$LocalIp\x22" 1
./localScripts/changeConfig.sh /home/ubuntu/antidote/rel/files/app.config pb_ip "\x22$LocalIp\x22" 1
./localScripts/changeConfig.sh /home/ubuntu/antidote/rel/files/antidote.config to_repl "$ReplList"
./localScripts/changeConfig.sh /home/ubuntu/antidote/rel/files/antidote.config do_repl true 
