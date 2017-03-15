#!/usr/bin/env bash
# This script sends an ssh command to the nodes in an input file
# The nodes should have installed fmk under ~/FMKe

# INPUT:
# 1) NodesListFile: THE filename with the list of nodes
# 2) The username of SSH to access the nodes
# 3) The private key to be used to connect to the nodes
# 4) CleanMake = TRUE/FALSE: make clean && make rel or not
# 5) GitBranch: the branch of git we want to checkout

# This is only necessary when running on OS X, erlang 19
# might be removed, but won't harm otherwise...
PATH="$PATH:/opt/local/lib/erlang/erts-8.1/bin/"
# Example: if we want to make rel in antidote, we will call this script like: NodesListFile="~/basho_bench/script/FMKe/antidote-nodes-list.txt" ./master-start-antidote-workers.sh
chmod +x ~/basho_bench//script/FMKe/*
chmod +x ~/FMKe/bin/*
chmod +x ~/antidote/bin/*

if [ -z "$NodesListFile" ]; then
    NodesListFile=~/basho_bench/script/FMKe/bench-nodes-list.txt
fi
if [ -z "$CleanMake" ]; then
    CleanMake=TRUE
fi
if [ -z "$GitBranch" ]; then
    GitBranch="master"
fi
if [ -z "$PrivateKey" ]; then
    PrivateKey=~/.ssh/antidotedbKeyPair.pem
fi
chmod 600 $PrivateKey


SshOptions="-o StrictHostKeyChecking=no -i $PrivateKey"

Nodes=`cat ${NodesListFile}`
echo "Nodes are: ${Nodes}"


for Item in ${Nodes}
do
    Command="ssh $SshOptions $USER@$Item GitBranch=${GitBranch} CleanMake=${CleanMake} IP=${Item} ~/basho_bench/script/FMKe/worker-start-fmk.sh"
    echo "Sending ssh command to ${Item}:"
    echo "${Command}"
    eval $Command &
done
