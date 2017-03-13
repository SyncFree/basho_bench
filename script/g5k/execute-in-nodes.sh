#!/usr/bin/env bash

set -eo pipefail

# Execute a command on a set of nodes or ips
doForNodes () {
  local nodes="$1"
  local command="$2"

  if [[ $# -ge 3 && "$3" == "-debug" ]]; then
    for node in ${nodes}; do
      # If the command contains the word 'localhost', replace it with the current node or ip
      ssh -i ${EXPERIMENT_PRIVATE_KEY} -T \
          -o ConnectTimeout=3 \
          -o StrictHostKeyChecking=no \
          root@"${node}" "${command//localhost/${node}}"

      if [[ $# -eq 4 ]]; then
        sleep $4
      fi
    done
  else
    local pids=()
    for node in ${nodes}; do
      ssh -i ${EXPERIMENT_PRIVATE_KEY} -T \
          -o ConnectTimeout=3 \
          -o StrictHostKeyChecking=no \
          root@"${node}" "${command//localhost/${node}}" &

      pids+=($!)
    done

    local fail=0
    for pid in "${pids[@]}"; do
      wait ${pid} || fail=$((fail + 1))
    done

    if [[ "${fail}" != "0" ]]; then
      exit 1
    fi
  fi
}

doForNodes "$@"
