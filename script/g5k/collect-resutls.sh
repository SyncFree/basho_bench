#!/usr/bin/env bash

set -eo pipefail

IFS=$'\r\n' GLOBIGNORE='*' :;

SELF=$(readlink $0 || true)
if [[ -z ${SELF} ]]; then
  SELF=$0
fi

cd $(dirname "$SELF")

if [[ -z ${CONFIG} ]]; then
  CONFIG=configuration.sh
fi
source $CONFIG








# For each node / ip in a file (one each line),
# ssh into it and run the given command
doForNodesIn () {
   echo "[DOFORNODESIN] executing $2 at nodes : $(cat "$1")"
  ./execute-in-nodes.sh "$(cat "$1")" "$2"
}


# Node Name -> IP
getIPs () {
  [[ -f ${ALL_IPS} ]] && rm ${ALL_IPS}
  [[ -f ${BENCH_IPS} ]] && rm ${BENCH_IPS}
  [[ -f ${ANT_IPS} ]] && rm ${ANT_IPS}

  while read n; do dig +short "${n}"; done < ${ANT_NODES} > ${ANT_IPS}
  while read n; do dig +short "${n}"; done < ${BENCH_NODEF} > ${BENCH_IPS}
  while read n; do dig +short "${n}"; done < ${ALL_NODES} > ${ALL_IPS}
  echo "[GATHER_MACHINES]: ANTIDOTE IPS: ${ANT_IPS}"
  echo "[GATHER_MACHINES]: BENCH IPS: ${BENCH_IPS}"
}


# Get all nodes in reservation, split them into
# antidote and basho bench nodes.
gatherMachines () {
  echo "[GATHER_MACHINES]: Starting..."
  local antidote_nodes_per_site=$((DCS_PER_SITE * ANTIDOTE_NODES))
  local benchmark_nodes_per_site=$((BENCH_NODES))
  [[ -f ${ALL_NODES} ]] && rm ${ALL_NODES}
  [[ -f ${ANT_NODES} ]] && rm ${ANT_NODES}
  [[ -f ${BENCH_NODEF} ]] && rm ${BENCH_NODEF}

  # Remove all blank lines and repeats
  # and add those to the full machine list
  oargridstat -w -l ${GRID_JOB_ID} | sed '/^$/d' \
    | awk '!seen[$0]++' > ${ALL_NODES}

  # For each site, get the list of nodes and slice
  # them into antidote and basho bench lists, depending on
  # the configuration given.
  for site in "${sites[@]}"; do
    awk < ${ALL_NODES} "/${site}/ {print $1}" \
      | tee >(head -${antidote_nodes_per_site} >> ${ANT_NODES}) \
      | sed "1,${antidote_nodes_per_site}d" \
      | head -${benchmark_nodes_per_site} >> ${BENCH_NODEF}
  done

  # Override the full node list, in case we didn't pick all the nodes
  cat ${BENCH_NODEF} ${ANT_NODES} > ${ALL_NODES}

  getIPs

  echo "[GATHER_MACHINES]: Done"
}


# Calculates the number of datacenters in the benchmark
getTotalDCCount () {
  # FIX: Assumes that all sites have the same number of data centers
  local sites_size=${#sites[*]}
  local total_dcs=$(( sites_size * DCS_PER_SITE))
  echo ${total_dcs}
}

# Creates unique erlang cookies for all basho_bench and antidote nodes.
# All nodes of the same type inside the same datacenter hold the same cookie.
createCookies () {
  echo -e "\t[CREATE_COOKIES]: Starting..."

  local total_dcs=$1

  [[ -f ${ALL_COOKIES} ]] && rm ${ALL_COOKIES}
  [[ -f ${ANT_COOKIES} ]] && rm ${ANT_COOKIES}
  [[ -f ${BENCH_COOKIES} ]] && rm ${BENCH_COOKIES}

  for n in $(seq 1 ${total_dcs}); do
    # In each datacenter, all antidote nodes must have the same cookie
    for _ in $(seq 1 ${ANTIDOTE_NODES}); do
      echo "dccookie${n}" | tee -a ${ALL_COOKIES} >> ${ANT_COOKIES}
    done

    # In each datacenter, all basho_bench nodes must have the same cookie
    for _ in $(seq 1 ${BENCH_NODES}); do
      echo "dccookie${n}" | tee -a ${ALL_COOKIES} >> ${BENCH_COOKIES}
    done

  done

  echo -e "\t[CREATE_COOKIES]: Done"
}


# TODO: Really necessary? How do we distribute them?
# Send erlang cookies to the appropiate antidote nodes.
distributeCookies () {
  echo -e "\t[DISTRIBUTE_COOKIES]: Starting..."

  local cookie_array=($(cat ${ALL_COOKIES}))
  local cookie_dev_config="/tmp/antidote/rel/vars/dev_vars.config.src"
  local cookie_config="/tmp/antidote/config/vars.config"

  local c=0
  while read node; do
    local cookie=${cookie_array[$c]}
    local command="sed -i.bak 's|^{cookie.*|{cookie, ${cookie}}.|g' ${cookie_config} ${cookie_dev_config}"
    ssh -i ${EXPERIMENT_PRIVATE_KEY} -T \
        -o ConnectTimeout=3 \
        -o StrictHostKeyChecking=no root@${node} "${command}"
    c=$((c + 1))
  done < ${ANT_IPS}

  echo -e "\t[DISTRIBUTE_COOKIES]: Done"
}

transferIPs () {
  local bench_node_file="$1"
  local antidote_ips_file="$2"
  local antidote_ips_file_name=$(basename "${antidote_ips_file}")

  local bench_dc_nodes=( $(< "${bench_node_file}") )
  echo "[DISTRIBUTE NODES FILES ] copying dc files to nodes!!!"
  for node in "${bench_dc_nodes[@]}"; do
    command="scp -i ${EXPERIMENT_PRIVATE_KEY} .dc_nodes* root@${node}:/root/"
    echo "running: $command"
    $command
  done
}

changeRingSize () {
  echo "[SETUP_TESTS]: Starting..."

  local dc_size=${ANTIDOTE_NODES}
  ./change-partition-size.sh ${dc_size}

  echo "[SETUP_TESTS]: Done"
}


collectResults () {
  echo "[COLLECTING_RESULTS]: Starting..."
  [[ -d "${RESULTSDIR}" ]] && rm -r "${RESULTSDIR}"
  mkdir -p "${RESULTSDIR}"
  local bench_nodes=( $(< ${BENCH_NODEF}) )
  for node in "${bench_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} root@${node}:/root/test* "${RESULTSDIR}"
  done

    echo "[COLLECTING_RESULTS]: Done..."
  echo "[DELETING RESULTS FROM NODES]: Starting..."

  doForNodesIn ${BENCH_NODEF} \
  "rm -rf /root/test*"

    echo "[DELETING RESULTS FROM NODES]: DONE..."

}

tarEverything () {
  pushd "${SCRATCHFOLDER}" > /dev/null 2>&1
  local tar_name="$(basename "${SCRATCHFOLDER}")-$GLOBAL_TIMESTART"
  command="tar -czf ../${tar_name}.tar ${SCRATCHFOLDER}"
  $command
  rm -rf "${SCRATCHFOLDER}"
  popd > /dev/null 2>&1


}
collectStalenessResults(){
echo "[COLLECTING_RESULTS]: Taring antidote staleness logs at all antidote nodes..."
  doForNodesIn ${ANT_NODES} \
  "cd /tmp/antidote; \
  chmod +x ./bin/physics_staleness/tar-staleness-results-g5k.sh
  ./bin/physics_staleness/tar-staleness-results-g5k.sh -${GLOBAL_TIMESTART}-${ANTIDOTE_PROTOCOL}-${STRICT_STABLE}"

  echo "[COLLECTING_RESULTS]: Done TARING"


  [[ -d "${RESULTSSTALEDIR}" ]] && rm -r "${RESULTSSTALEDIR}"
   mkdir -p "${RESULTSSTALEDIR}"

  echo "[COLLECTING TARED STALENESS RESULTS FROM ANTIDOTE]: ......"
  local antidote_nodes=( $(< ${ANT_NODES}) )
  for node in "${antidote_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} root@${node}:/root/*StalenessResults.tar "${RESULTSSTALEDIR}"
  done
    echo "[COLLECTING TARED STALENESS RESULTS FROM ANTIDOTE]: Done, put them in $RESULTSSTALEDIR......"
}

run () {
  export antidote_ip_file=".antidote_ip_file"
  collectResults >> ${LOGDIR}/collect-results-${GLOBAL_TIMESTART} 2>&1
  collectStalenessResults >> ${LOGDIR}/collect-staleness-results-${GLOBAL_TIMESTART} 2>&1
  tarEverything
  echo "done collecting staleness results"
}

## get, from each antidote instance, staleness logs:
## 1. sync the logs (as they are written asynchronously)
## 2. copy them to a safe plce
## 3. truncate them, to start new experiments.
CopyStalenessLogs () {
  local total_dcs=$1

    # Get only one antidote node per DC
  for i in $(seq 1 ${total_dcs}); do
    local clusterhead=$(head -1 .dc_nodes${i})
    nodes_str+="'antidote@${clusterhead}' "
  done

  clusterhead=$(head -1 .dc_nodes1)
  nodes_str=${nodes_str%?}

#  local head=$(head -1 .dc_nodes1)

  echo "[SYNCING ANTIDOTE STALENESS LOGS]: SYNCING antidote staleness logs... "
  echo "[SYNCING ANTIDOTE STALENESS LOGS]:executing in node $clusterhead /root/antidote/bin/sync_staleness_logs.erl ${nodes_str}"
  ./execute-in-nodes.sh "$clusterhead" \
        "chmod +x /tmp/antidote/bin/sync_staleness_logs.erl && \
        /tmp/antidote/bin/sync_staleness_logs.erl ${nodes_str}"
  echo -e "\t[SYNCING AND CLOSING ANTIDOTE STALENESS LOGS]: Done"


  dirStale="_build/default/rel/antidote/benchLogs/Staleness/Stale-$KEYSPACE-$ROUNDS-$READS-$UPDATES-$BENCH_CLIENTS_PER_INSTANCE"
  dirLog="_build/default/rel/antidote/benchLogs/Log/Log-$KEYSPACE-$ROUNDS-$READS-$UPDATES-$BENCH_CLIENTS_PER_INSTANCE"

  command1="\
    cd /tmp/antidote && \
    mkdir -p $dirStale && \
    cp _build/default/rel/antidote/data/Staleness* $dirStale && \
    mkdir -p $dirLog && \
    cp _build/default/rel/antidote/log/*.log $dirLog"
  echo "[COPYING STALENESS LOGS]: moving logs to directory: $dirStale at all antidote nodes... "
  echo "[COPYING LOGS]: moving logs to directory: $dirLog at all antidote nodes... "
  echo "\t[GetAntidoteLogs]: executing $command1 at ${antidote_nodes[@]}..."
    doForNodesIn ".antidote_ip_file" "${command1}"
   echo "[COPYING STALENESS LOGS]: done! "

  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]: Truncating antidote staleness logs... "
  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]:executing in node $clusterhead /tmp/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
  ./execute-in-nodes.sh "$clusterhead" \
        "/tmp/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
  echo -e "\t[TRUNCATING ANTIDOTE STALENESS LOGS]: Done"
}

startBGprocesses() {
  local total_dcs=$1
    # Get only one antidote node per DC
  for i in $(seq 1 ${total_dcs}); do
    local clusterhead=$(head -1 .dc_nodes${i})
    nodes_str+="'antidote@${clusterhead}' "
  done
  nodes_str=${nodes_str%?}
#  local head=$(head -1 .dc_nodes1)
  local join_cluster="\
    /tmp/antidote/bin/start_bg_processes.erl ${nodes_str}
  "
  ./execute-in-nodes.sh "${nodes_str}" "${join_cluster}" "-debug"
}

    if [[ -z ${GLOBAL_TIMESTART} ]]; then
  export GLOBAL_TIMESTART=$(date +"%Y-%m-%d-%s")
fi


    sites=( "${SITES[@]}" )


    ANTIDOTE_IP_FILE="$1"



    if [[ "${RESERVE_SITES}" == "true" ]]; then
      echo "[RESERVING_SITES]: Starting..."
      export GRID_JOB_ID=$(reserveSites)

      if [[ -z "${GRID_JOB_ID}" ]]; then
        echo "Uh-oh! Something went wrong while reserving. Maybe try again?"
        exit 1
      fi

      sed -i.bak '/^GRID_JOB_ID.*/d' configuration.sh
      echo "GRID_JOB_ID=${GRID_JOB_ID}" >> configuration.sh
      echo "[RESERVING_SITES]: Done. Successfully reserved with id ${GRID_JOB_ID}"
    else
      echo "[RESERVING_SITES]: Skipping"
    fi

    # Delete the reservation if script is killed
    trap 'cancelJob ${GRID_JOB_ID}' SIGINT SIGTERM

    SCRATCHFOLDER="/home/$(whoami)/grid-benchmark-${GRID_JOB_ID}"
    export LOGDIR=${SCRATCHFOLDER}/logs/${GLOBAL_TIMESTART}
    RESULTSDIR=${SCRATCHFOLDER}/results/bench-${GLOBAL_TIMESTART}-${ANTIDOTE_PROTOCOL}-${STRICT_STABLE}
    RESULTSSTALEDIR=${SCRATCHFOLDER}/results-staleness/staleness-${GLOBAL_TIMESTART}-${ANTIDOTE_PROTOCOL}-${STRICT_STABLE}

    export EXPERIMENT_PRIVATE_KEY=${SCRATCHFOLDER}/key
    EXPERIMENT_PUBLIC_KEY=${SCRATCHFOLDER}/exp_key.pub

    export ALL_NODES=${SCRATCHFOLDER}/.all_nodes
    export BENCH_NODEF=${SCRATCHFOLDER}/.bench_nodes
    export ANT_NODES=${SCRATCHFOLDER}/.antidote_nodes

    export ALL_IPS=${SCRATCHFOLDER}/.all_ips
    BENCH_IPS=${SCRATCHFOLDER}/.bench_ips
    export ANT_IPS=${SCRATCHFOLDER}/.antidote_ips

    export ALL_COOKIES=${SCRATCHFOLDER}/.all_cookies
    ANT_COOKIES=${SCRATCHFOLDER}/.antidote_cookies
    BENCH_COOKIES=${SCRATCHFOLDER}/.bench_cookies

    run

