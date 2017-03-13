#!/usr/bin/env bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ${0##*/} nodes-per-dc"
  exit 1
fi

setRingSize () {
  local nodes_per_dc=$1
  if [[ ${nodes_per_dc} -lt 2 ]]; then
    echo 8
  elif [[ ${nodes_per_dc} -lt 3 ]]; then
    echo 128
  elif [[ ${nodes_per_dc} -lt 14 ]]; then
    echo 256
  elif [[ ${nodes_per_dc} -lt 33 ]]; then
    echo 128
  elif [[ ${nodes_per_dc} -lt 65 ]]; then
    echo 256
  else
    echo 512
  fi
}

# TODO: Double-check that this path is correct
# TODO: rm -r ./antidote/rel/antidote/data/* ?
changePartition () {
  local command="
    cd ~/antidote && \
    sed -i.bak \
      's|.*ring_creation_size.*|{ring_creation_size, $1}.|g' \
      config/vars.config rel/vars/dev_vars.config.src
  "

  ./execute-in-nodes.sh "$(cat ${ANT_NODES})" "${command}" "-debug"
}

run () {
  local ring_size=$(setRingSize $1)
  changePartition "${ring_size}"
}

run "$@"
