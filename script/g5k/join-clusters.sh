#!/usr/bin/env bash

set -eo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: ${0##*/} dc-size total-dcs"
  exit 1
fi

joinLocalDC () {
  local dc_nodes=( $(cat "${1}") )
  local dc_size=${#dc_nodes[*]}

  local head="${dc_nodes[0]}"

  local nodes_str
  for node in "${dc_nodes[@]}"; do
    nodes_str+="'antidote@${node}' "
  done

  nodes_str=${nodes_str%?}

  local join_dc="\
    ./antidote/bin/join_cluster_script.erl ${nodes_str}
  "

  ./execute-in-nodes.sh "${head}" "${join_dc}" "-debug"
}

joinInterDCCluster() {
  local dc_size=$1
  local total_dcs=$2

    # Get only one antidote node per DC
  for i in $(seq 1 ${total_dcs}); do
    local head${i}=$(head -1 .dc_nodes${i})
    nodes_str+="'antidote@$head${i}' "
  done

#  local i=1
#  local nodes_str
#  while [[ i -lt ${total_dcs} ]]; do
#    nodes_str+="'antidote@$(sed -n "${i}p" ${ANT_IPS})' "
#    i=$((i + dc_size))
#  done

  nodes_str=${nodes_str%?}

  local join_cluster="\
    ./antidote/bin/join_dcs_script.erl ${nodes_str}
  "
  ./execute-in-nodes.sh "${head1}" "${join_cluster}" "-debug"
}


joinNodes () {
  local dc_size=$1
  local total_dcs=$2

  # No point in clustering if we have only 1 node
  if [[ ${dc_size} -le 1 ]]; then
    echo -e "\t[BUILDING_LOCAL_CLUSTER]: only starting background processes"
    joinLocalDC .dc_nodes1
  else
    echo -e "\t[BUILDING_LOCAL_CLUSTER]: Starting..."

    local offset=1
    for i in $(seq 1 ${total_dcs}); do
        line_end=`expr $offset + $dc_size - 1`
        sed -n "${offset}, ${line_end}p" "${ANT_IPS}" > .dc_nodes${i}

      joinLocalDC .dc_nodes${i} >> "${LOGDIR}"/join-local-dc${GLOBAL_TIMESTART} 2>&1
      offset=$((offset + dc_size))
    done

    echo -e "\t[BUILDING_LOCAL_CLUSTER]: Done"
  fi

  # No point in inter-dc clustering if we have only 1 dc
  if [[ ${total_dcs} -le 1 ]]; then
    echo -e "\t[INTER_DC_CLUSTERING]: Skipping"
    exit
  fi

  echo -e "\t[INTER_DC_CLUSTERING]: Starting..."
  joinInterDCCluster ${dc_size} ${total_dcs} >> "${LOGDIR}"/join-inter-dc${GLOBAL_TIMESTART} 2>&1
  echo -e "\t[INTER_DC_CLUSTERING]: Done"
}

run () {
  local dc_size=$1
  local total_dcs=$2

  joinNodes ${dc_size} ${total_dcs}
}

run "$@"
