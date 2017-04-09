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

# Boot the machines and load the os image.
DEPLOY_IMAGE=true

# Provision the nodes with Antidote / basho_bench
DOWNLOAD_ANTIDOTE=true

DOWNLOAD_BENCH=true

# Download and compile antidote and basho bench from scratch
CLEAN_ANTIDOTE=false

# Make a basho_bench git pull and make at bench nodes
CLEAN_BENCH=false

# Connect servers in clusters and DCs
CONNECT_CLUSTERS_AND_DCS=true

# Number of "data centers" per g5k site
# For example, saying DCS_PER_SITE=2 and ANTIDOTE_NODES=1
# will create 2 antidote nodes in total, one on each data center
DCS_PER_SITE=3

# Number of nodes running Antidote PER DC!!!!!!
ANTIDOTE_NODES=15
# Number of nodes running Basho Bench per DC
BENCH_NODES=6
# Number of instances of basho_bench to run per node
BENCH_INSTANCES=6

#force time sync before running
FORCE_NTP_SYNC=false

# git repository of the antidote code (useful to test forks)
ANTIDOTE_URL="https://github.com/SyncFree/antidote.git"
# git branch of antidote to run the experiment on
ANTIDOTE_BRANCH="ec"

ANTIDOTE_PROTOCOLS=( "ec" )

# git repository of the basho_bench code (useful to test forks)
BENCH_URL="https://github.com/SyncFree/basho_bench.git"
# git branch of Basho Bench to use
BENCH_BRANCH="ec_old"

# Name of the benchmark configuration file to use
BENCH_FILE="antidote_pb.config"

# Comment or remove this line when RESERVE_SITES=true, it will be added automatically.
GRID_JOB_ID=58110

# workloads
KEY_SPACES=( 10000000 1000000 )
ROUND_NUMBER=( 10 )
READ_NUMBER=( 100 100 100 )
UPDATE_NUMBER=( 2 10 100 )
BENCH_THREAD_NUMBER=( 20 30 40 50 )

