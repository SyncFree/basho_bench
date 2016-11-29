#!/bin/bash

cd /root/basho_bench1/basho_bench/
mkdir logs

AllNodes=`cat /root/basho_bench1/basho_bench/script/allnodesfull`
echo All nodes "$AllNodes"

# TODO: Why sophia?
command="\
  sed -i.bak 's|^export http_proxy.*|export http_proxy=http://proxy.sophia.grid5000.fr:3128|' ~/.bashrc && \
  sed -i.bak 's|^export https_proxy.*|export https_proxy=https://proxy.sophia.grid5000.fr:3128|' ~/.bashrc
"

echo Running proxy config
echo

echo Performing: ./script/parallel_command.sh "$AllNodes" "${command}"
./script/parallel_command.sh "$AllNodes" "${command}" >> logs/config_proxy
