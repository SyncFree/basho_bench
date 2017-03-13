#!/usr/bin/env bash

# The private / public key pair used for this experiment
PRKFILE=~/.ssh/a_exp
PBKFILE=~/.ssh/a_exp.pub

# The url of the k3 env to deploy on the nodes
K3_IMAGE=/home/$(whoami)/public/antidote-images/latest/antidote.env

# Different g5k sites to run the benchmark
SITES=( "nancy" )

# Reserve sites and nodes through oargridsub
RESERVE_SITES=true

# Boot the machines and load the os image.
DEPLOY_IMAGE=true

# Provision the nodes with Antidote / basho_bench
PROVISION_IMAGES=true

# Download and compile antidote and basho bench from scratch
CLEAN_RUN=true

# Number of "data centers" per g5k site
# For example, saying DCS_PER_SITE=2 and ANTIDOTE_NODES=1
# will create 2 antidote nodes in total, one on each data center
DCS_PER_SITE=1

# Number of nodes running Antidote per DC
ANTIDOTE_NODES=1
# Number of nodes running Basho Bench per DC
BENCH_NODES=1
# Number of instances of basho_bench to run per node
BENCH_INSTANCES=1

# git repository of the antidote code (useful to test forks)
ANTIDOTE_URL="https://github.com/ergl/antidote.git"
# git branch of antidote to run the experiment on
ANTIDOTE_BRANCH="fix-join-scripts"

# git repository of the basho_bench code (useful to test forks)
BENCH_URL="https://github.com/SyncFree/basho_bench.git"
# git branch of Basho Bench to use
BENCH_BRANCH="antidote_pb-rebar3-erlang19"

# Name of the benchmark configuration file to use
BENCH_FILE="antidote_pb.config"
