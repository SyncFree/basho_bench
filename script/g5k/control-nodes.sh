#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
  echo "Usage: ${0##*/} --start | --stop"
  exit 1
fi

startNodes () {
  local antidote_nodes=( $(cat ${ANT_NODES}) )
  for node in "${antidote_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} ./control-nodes-remote.sh root@${node}:/root/
  done

  ./execute-in-nodes.sh "$(cat ${ANT_NODES})" "./control-nodes-remote.sh start" "-debug"
}

stopNodes () {
  local command="\
    [[ -f control-nodes-remote.sh ]] && ./control-nodes-remote.sh stop; \
    pkill beam; \
    rm -rf antidote/_build/default/rel/antidote/data/*; \
    rm -rf antidote/_build/default/rel/antidote/log/*; \
  "
  ./execute-in-nodes.sh "$(cat ${ANT_NODES})" "${command}" "-debug"
}

case "$1" in
  "--start") startNodes;;
  "--stop") stopNodes
esac
