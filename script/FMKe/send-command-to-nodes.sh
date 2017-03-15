#!/usr/bin/env bash
# This script sends an ssh command to the nodes in an input file

# INPUT:
# 1) THE filename with the list of nodes
# 2) The command to be executed


# Example: if we want to make rel in antidote, we will call this script like: ./send-command-to-nodes.sh antidote-nodes-list.txt 'make rel'

BenchNodes=`cat ${1}`

for Item in ${BenchNodes}
do
    RunCommand= "$2"
    echo "sending ssh command to ${Item}:"
    echo "${RunCommand}"
    spawn eval $RunCommand
done