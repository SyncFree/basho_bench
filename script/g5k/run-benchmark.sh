#!/usr/bin/env bash

#set -eo pipefail

export KEY_SPACES=( 10000000 )
export ROUND_NUMBER=( 10 )
export READ_NUMBER=( 100 )
export UPDATE_NUMBER=( 2 )

#export KEY_SPACES=( 10000000 1000000 100000 10000 )
#export ROUND_NUMBER=( 1 2 5 10 )
#export READ_NUMBER=( 100 100 90 )
#export UPDATE_NUMBER=( 1 2 10 )

if [[ $# -ne 1 ]]; then
  echo "Usage: ${0##/*} total-dcs"
  exit 1
fi

source configuration.sh


AntidoteCopyAndTruncateStalenessLogs () {
  dir="_build/default/rel/antidote/data/Stale-$GLOBAL_TIMESTART-$KEYSPACE-$ROUNDS-$READS-$UPDATES"

  command1="cd /home/root/antidote/; \
    mkdir -p $dir; \
    cp _build/default/rel/antidote/data/Staleness* $dir "

  antidote_nodes=($(< ".antidote_ip_file"))

  echo "\t[GetAntidoteLogs]: executing $command1 at ${antidote_nodes[@]}..."

  ./execute-in-nodes.sh "${antidote_nodes[@]}" \
        "$command1"

  for node in ${antidote_nodes[@]}; do
    nodes_str+="'antidote@${node}' "
  done

  node1=${antidote_nodes[0]}

  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]: Truncating antidote staleness logs... "
  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]:executing in node $node1 /home/root/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
  ./execute-in-nodes.sh "$node1" \
        "/home/root/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
  echo -e "\t[TRUNCATING ANTIDOTE STALENESS LOGS]: Done"
}

runRemoteBenchmark () {
# THIS FUNCTION WILL MANY ROUNDS FOR ANTIDOTE:
# ONE FOR EACH KEYSPACE, NUMBER OF ROUNDS, AND READ/UPDATE RATIO.
# In between rounds, it will copy antidote logs to a folder in data, and truncate them.
  local antidote_ip_file="$3"
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
        #NOW RUN A BENCH

        local benchfilename=$(basename $BENCH_FILE)
        echo "[RunRemoteBenchmark] Running bench with: KEY_SPACES=$KEYSPACE ROUND_NUMBER=$ROUNDS READ_NUMBER=$READS UPDATES=$UPDATES"

        echo "./run-benchmark-remote.sh ${antidote_ip_file} ${BENCH_INSTANCES} ${benchfilename} ${KEYSPACE} ${ROUNDS} ${READS} ${UPDATES}"

        ./execute-in-nodes.sh "$(< ${BENCH_NODEF})" \
        "./run-benchmark-remote.sh ${antidote_ip_file} ${BENCH_INSTANCES} ${benchfilename} ${KEYSPACE} ${ROUNDS} ${READS} ${UPDATES}"

        echo "[RunRemoteBenchmark] done."
        # yea, that.
        AntidoteCopyAndTruncateStalenessLogs
        # Wait for the cluster to settle between runs
#        sleep 60
        re=$((re+1))
      done
    done
  done
}
run () {
  export ANTIDOTE_IP_FILE=".antidote_ip_file"
  command="runRemoteBenchmark ${BENCH_INSTANCES} ${BENCH_FILE} ${ANTIDOTE_IP_FILE}"
  echo "running $command"
  $command



}
run "$@"
