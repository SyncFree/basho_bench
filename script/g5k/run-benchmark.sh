#!/usr/bin/env bash

#set -eo pipefail

export KEY_SPACES=( 10000000 1000000 100000 10000 )
export ROUND_NUMBER=( 1 2  10 10 )
export READ_NUMBER=( 100 100 90 75 50 )
export UPDATE_NUMBER=( 1 2 10 25 50 )

if [[ $# -ne 1 ]]; then
  echo "Usage: ${0##/*} total-dcs"
  exit 1
fi

source configuration.sh


AntidoteCopyAndTruncateStalenessLogs () {
  dir="_build/default/rel/antidote/data/Stale-$GLOBAL_TIMESTART-$KEYSPACE-$ROUNDS-$READS-$UPDATES"
  echo -e "\t[GetAntidoteLogs]: creating command to send logs to dir $dir..."
  local command="\
    cd /home/root/antidote/; \
    mkdir -p $dir; \
    cp _build/_build/default/rel/antidote/data/Staleness* $dir; \
  "
  dir="_build/default/rel/antidote/data/Stale-$GLOBAL_TIMESTART-$KEYSPACE-$ROUNDS-$READS-$UPDATES"; \

  local nodes_str=( $(cat ".antidote_ip_file") )
  for node in "${dc_nodes[@]}"; do
    nodes_str+="'antidote@${node}' "
  done

  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]: Truncating antidote staleness logs... "
  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]:/home/root/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
  exec "/home/$(whoami)/antidote/bin/physics_staleness/truncate_staleness_logs.erl ${nodes_str}"
  echo -e "\t[TRUNCATING ANTIDOTE STALENESS LOGS]: Done"
}

collectResults () {
  echo "[COLLECTING_RESULTS]: Starting..."
  [[ -d "${RESULTSDIR}" ]] && rm -r "${RESULTSDIR}"
  mkdir -p "${RESULTSDIR}"
  local bench_nodes=( $(< ${BENCH_NODEF}) )
  local antidote_nodes=( $(< ${ANT_NODES}) )
  for node in "${bench_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} root@${node}:/root/test* "${RESULTSDIR}"
  done
  echo "[COLLECTING_RESULTS]: Done"

  echo "[COLLECTING_RESULTS]: COLLECTING ANTIDOTE STALENESS LOGS..."
  for node in "${antidote_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} root@${node}:/home/root/antidote/_build/default/rel/antidote/data/*.tar "${RESULTSSTALEDIR}"
  done
  echo "[COLLECTING_RESULTS]: Done"

  echo "[MERGING_RESULTS]: Starting..."
  ./merge-results.sh "${RESULTSDIR}"
  echo "[MERGING_RESULTS]: Done"

  pushd "${RESULTSDIR}" > /dev/null 2>&1
  local tar_name=$(basename "${RESULTSDIR}")
  tar -czf ../"${tar_name}".tar .
  popd > /dev/null 2>&1
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
        command="./run-benchmark-remote.sh ${antidote_ip_file} ${instances} ${benchfilename} ${KEYSPACE} ${ROUNDS} ${READS} ${UPDATES}"
        ./execute-in-nodes.sh "$(< ${BENCH_NODEF}) $command"
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
