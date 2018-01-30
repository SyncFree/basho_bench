#!/usr/bin/env bash

# The private / public key pair used for this experiment
PRKFILE=~/.ssh/id_rsa
PBKFILE=~/.ssh/id_rsa.pub

# The url of the k3 env to deploy on the nodes
K3_IMAGE=/home/bderegil/public/antidote-images/latest/antidote.env
# JUST RUN, NO CONFIG
JUST_RUN=false

# Reserve sites and nodes through oargridsub
RESERVE_SITES=false

# Different g5k sites to run the benchmark
SITES=( "nancy" )

# Comment or remove this line when RESERVE_SITES=true, it will be added automatically.
GRID_JOB_ID=60443

# Boot the machines and load the os image.
DEPLOY_IMAGE=false

# Provision the nodes with Antidote / basho_bench
DOWNLOAD_ANTIDOTE=true

DOWNLOAD_BENCH=true

# Download and compile antidote and basho bench from scratch
CLEAN_ANTIDOTE=true

# Make a basho_bench git pull and make at bench nodes
CLEAN_BENCH=true

# Connect servers in clusters and DCs
CONNECT_CLUSTERS_AND_DCS=true

# Number of "data centers" per g5k site
# For example, saying DCS_PER_SITE=2 and ANTIDOTE_NODES=1
# will create 2 antidote nodes in total, one on each data center
DCS_PER_SITE=1

# Run a bench_node per antidote node (and dismiss the BENCH_NODES param)
BENCH_THE_LOCAL_NODE=true
# Number of nodes running Antidote PER DC!!!!!!
ANTIDOTE_NODES=16 #PER DC!
# Number of nodes running Basho Bench per DC
BENCH_NODES=16 #PER DC!
# Number of instances of basho_bench to run per node
BENCH_INSTANCES=2 #PER BENCH_NODE!

#force time sync before running
FORCE_NTP_SYNC=false

# git repository of the antidote code (useful to test forks)
ANTIDOTE_URL="https://github.com/SyncFree/antidote.git"
# git branch of antidote to run the experiment on
ANTIDOTE_BRANCH="17-dec"

#possible protocols: cure, av, oc, ec, gr
ANTIDOTE_PROTOCOLS=( "cure" "av" "oc" "ec" )

# git repository of the basho_bench code (useful to test forks)
BENCH_URL="https://github.com/SyncFree/basho_bench.git"
# git branch of Basho Bench to use
BENCH_BRANCH="ec1"

# Name of the benchmark configuration file to use
BENCH_FILE="antidote_pb.config"




#5 facebook
KEY_SPACES=( 100000 )
ROUND_NUMBER=( 10 )
READ_NUMBER=( 100 100 100 100 )
UPDATE_NUMBER=( 1000 500 100 2 )
BENCH_THREAD_NUMBER=( 1 5 10 20 30 40 50 65 80)