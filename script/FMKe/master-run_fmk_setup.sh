#!/usr/bin/env bash


# This script runs, from the master machine, the fmk setup script.

#INPUT:
# 1) MY_IP: the IP address of this machine
# 2)

########################################################
    # Run (or not) the FMKe setup script
##########################################################
# Make the setup test executable
chmod +x ~/basho_bench//script/FMKe/*
chmod +x ~/FMKe/bin/*
chmod +x ~/antidote/bin/*

# This is only necessary when running on OS X, erlang 19
# might be removed, but won't harm otherwise...
PATH="$PATH:/home/ubuntu/kerl_dir/r18b03/bin/"

# first check that fmk is active (pingable) on that node:
FmkPing=pong #$(~/basho_bench/script/FMKe/ping.erl 'fmk@${MY_IP}')
echo "##Node:${MY_IP}:Pinging 'fmk@${MY_IP}', got: ${FmkPing}"
if [ "$FmkPing" = pong ] ; then
    # Run the setup test
        echo "##Node:${MY_IP}: cding into ~/FMKe"
        cd ~/FMKe/
        pwd
        SetupCommand="~/FMKe/test/fmk_setup_script.erl 1 fmk@${MY_IP}"
        echo "##Node:${MY_IP}: Running Setup script with command: "
        echo "##Node:${MY_IP}: ${SetupCommand}"
        eval ${SetupCommand}

fi
