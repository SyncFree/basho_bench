#!/usr/bin/env bash

#set -eo pipefail


if [[ $# -ne 1 ]]; then
  echo "Usage: ${0##/*} total-dcs"
  exit 1
fi

source configuration.sh

doForNodesIn () {
  ./execute-in-nodes.sh "$(cat "$1")" "$2"
}

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
  echo "[SYNCING ANTIDOTE STALENESS LOGS]:executing in node $clusterhead /tmp/antidote/bin/sync_staleness_logs.erl ${nodes_str}"
  ./execute-in-nodes.sh "$clusterhead" \
        "chmod +x /tmp/antidote/bin/sync_staleness_logs.erl && \
        /tmp/antidote/bin/sync_staleness_logs.erl ${nodes_str}"
  echo -e "\t[SYNCING ANTIDOTE STALENESS LOGS]: Done"


  dirStale="_build/default/rel/antidote/benchLogs/Staleness/Stale-$KEYSPACE-$ROUNDS-$READS-$UPDATES-$BENCH_CLIENTS_PER_INSTANCE"
  dirLog="_build/default/rel/antidote/benchLogs/Log/Log-$KEYSPACE-$ROUNDS-$READS-$UPDATES-$BENCH_CLIENTS_PER_INSTANCE"

  command1="\
    cd /tmp/antidote && \
    mkdir -p $dirStale && \
    cp _build/default/rel/antidote/data/Staleness* $dirStale && \
    mkdir -p $dirLog && \
    cp _build/default/rel/antidote/log/* $dirLog"

  echo "[COPYING STALENESS LOGS]: moving logs to directory: $dirStale at all antidote nodes... "
  echo "[COPYING LOGS]: moving logs to directory: $dirLog at all antidote nodes... "
  echo "\t[GetAntidoteLogs]: executing $command1 at ${antidote_nodes[@]}..."
    doForNodesIn ".antidote_ip_file" "${command1}"
   echo "[COPYING STALENESS LOGS]: done! "




#  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]: Truncating antidote staleness logs... "
#  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]:executing in node $clusterhead /root/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
#  ./execute-in-nodes.sh "$clusterhead" \
#        "/root/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
#  echo -e "\t[TRUNCATING ANTIDOTE STALENESS LOGS]: Done"
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

runRemoteBenchmark () {
  firstround=1
# THIS FUNCTION WILL MANY ROUNDS FOR ANTIDOTE:
# ONE FOR EACH KEYSPACE, NUMBER OF ROUNDS, AND READ/UPDATE RATIO.
# In between rounds, it will copy antidote logs to a folder in data, and truncate them.
  local antidote_ip_file="$3"
  local total_dcs="$4"
  local bench_nodes=( $(< ${BENCH_NODEF}) )
  echo "[RUN REMOTE BENCHMARK : ] bench_nodes=${bench_nodes[@]}"
  for node in "${bench_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} ./run-benchmark-remote.sh root@${node}:/root/
  done
  for keyspace in "${KEY_SPACES[@]}"; do
    export KEYSPACE=${keyspace}
    for rounds in "${ROUND_NUMBER[@]}"; do
      export ROUNDS=${rounds}
      local re=0
      for reads in "${READ_NUMBER[@]}"; do
        export UPDATES=${UPDATE_NUMBER[re]}
        export READS=${reads}
        for clients_per_bench_instance in "${BENCH_THREAD_NUMBER[@]}"; do
            export BENCH_CLIENTS_PER_INSTANCE=${clients_per_bench_instance}
            if [[ "${firstround}" == 1 ]]; then
                sleep 30
                firstround=0
            else
                echo "[STOP_ANTIDOTE]: Starting..."
                ./control-nodes.sh --stop
                echo "[STOP_ANTIDOTE]: Done"
                echo "[START_ANTIDOTE]: Starting..."
                ./control-nodes.sh --start
                echo "[START_ANTIDOTE]: Done"
            fi

#            no need to start bg processes as a restart does it itself
#            echo "[STARTING BG PROCESSES]"
#            startBGprocesses ${total_dcs} >> "${LOGDIR}"/start-bg-dc${GLOBAL_TIMESTART} 2>&1
#            echo "[DONE STARTING BG PROCESSES!]"
            # Wait for the cluster to settle between runs
            sleep 60


            #NOW RUN A BENCH
            local benchfilename=$(basename $BENCH_FILE)
            echo "[RunRemoteBenchmark] Running bench with: KEY_SPACES=$KEYSPACE ROUND_NUMBER=$ROUNDS READ_NUMBER=$READS UPDATES=$UPDATES"
            echo "./run-benchmark-remote.sh ${antidote_ip_file} ${BENCH_INSTANCES} ${benchfilename} ${KEYSPACE} ${ROUNDS} ${READS} ${UPDATES} ${ANTIDOTE_NODES} ${BENCH_CLIENTS_PER_INSTANCE}"
            ./execute-in-nodes.sh "$(< ${BENCH_NODEF})" \
            "./run-benchmark-remote.sh ${antidote_ip_file} ${BENCH_INSTANCES} ${benchfilename} ${KEYSPACE} ${ROUNDS} ${READS} ${UPDATES} ${ANTIDOTE_NODES} ${BENCH_CLIENTS_PER_INSTANCE}"
                        # yea, that.
            CopyStalenessLogs "${total_dcs}" >> "${LOGDIR}"/copy-staleness-logs-${GLOBAL_TIMESTART} 2>&1
            echo "[RunRemoteBenchmark] done."


        done
        re=$((re+1))
      done
    done
  done
}
run () {
  export TOTAL_DCS=$1
  export ANTIDOTE_IP_FILE=".antidote_ip_file"
  command="runRemoteBenchmark ${BENCH_INSTANCES} ${BENCH_FILE} ${ANTIDOTE_IP_FILE} ${TOTAL_DCS}"
  echo "running $command"
  $command
}
run "$@"
