#!/usr/bin/env bash

set -eo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ${0##/*} total-dcs"
  exit 1
fi

source configuration.sh

transferIPs () {
  local bench_node_file="$1"
  local antidote_ips_file="$2"
  local antidote_ips_file_name=$(basename "${antidote_ips_file}")

  local bench_dc_nodes=( $(< "${bench_node_file}") )
  for node in "${bench_dc_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} "${antidote_ips_file}" root@${node}:/root/${antidote_ips_file_name}
  done
}

prepareTests () {
  local total_dcs="$1"
  local antidote_ip_file="$2"
  ./prepare-clusters.sh ${ANTIDOTE_NODES} ${total_dcs}

  local ant_offset=0
  local bench_offset=0
  for _ in $(seq 1 ${total_dcs}); do
    head -$((ANTIDOTE_NODES + ant_offset)) "${ANT_IPS}" > "${antidote_ip_file}"
    head -$((BENCH_NODES + bench_offset)) "${BENCH_NODEF}" > .dc_bench_nodes

    transferIPs .dc_bench_nodes "${antidote_ip_file}"

    ant_offset=$((ant_offset + ANTIDOTE_NODES))
    bench_offset=$((bench_offset + BENCH_NODES))
  done
}

changeReadWriteRatio () {
  echo "[changeReadWriteRatio] Changing config files to send to nodes..."
  local config_file="$1"
  echo "Rounds = ${ROUNDS}"
  echo "READS = ${READS}"
  echo "UPDATES = ${UPDATES}"
  sed -i.bak "s|^{num_read_rounds.*|{num_read_rounds, ${ROUNDS}}.|g" "${config_file}"
  sed -i.bak "s|^{num_reads.*|{num_reads, ${READS}}.|g" "${config_file}"
  sed -i.bak "s|^{num_updates.*|{num_updates, ${UPDATES}}.|g" "${config_file}"
}

changeAntidoteIPs () {
  local config_file="$1"
  local IPS=( $(< ${ANTIDOTE_IP_FILE}) )

  local ips_string
  for ip in "${IPS[@]}"; do
    ips_string+="'${ip}',"
  done
  ips_string=${ips_string%?}

  echo "Antidote IPS: ${ips_string}"

  sed -i.bak "s|^{antidote_pb_ips.*|{antidote_pb_ips, [${ips_string}]}.|g" "${config_file}"
}

changeKeyGen () {
  local config_file="$1"
  sed -i.bak "s|^{key_generator.*|{key_generator, {pareto_int, ${KEYSPACE}}}.|g" "${config_file}"
}

changeOPs () {
  local config_file="$1"
  # TODO: Config
  local ops="[{update_only_txn, 1}]"
  sed -i.bak "s|^{operations.*|{operations, ${ops}}.|g" "${config_file}"
}

changeBashoBenchConfig () {
#  local config_file="$1"
  changeAntidoteIPs "${CONFIG_FILE}"
#  changeAntidoteCodePath "${config_file}"
#  changeAntidotePBPort "${config_file}"
#  changeConcurrent "${config_file}"
  changeReadWriteRatio "${CONFIG_FILE}"
  changeKeyGen "${CONFIG_FILE}"
}

AntidoteCopyAndTruncateStalenessLogs () {
  dir="_build/default/rel/antidote/data/Stale-$GLOBAL_TIMESTART-$KEYSPACE-$ROUNDS-$READS-$UPDATES"
  echo -e "\t[GetAntidoteLogs]: creating command to send logs to dir $dir..."
  local command="\
    cd ~/antidote/; \
    mkdir -p $dir; \
    cp _build/_build/default/rel/antidote/data/Staleness* $dir; \
  "
  dir="_build/default/rel/antidote/data/Stale-$GLOBAL_TIMESTART-$KEYSPACE-$ROUNDS-$READS-$UPDATES"; \

  local nodes_str=( $(cat ".antidote_ip_file") )
  for node in "${dc_nodes[@]}"; do
    nodes_str+="'antidote@${node}' "
  done

  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]: Truncating antidote staleness logs... "
  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]:~/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
  exec "~/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
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
    scp -i ${EXPERIMENT_PRIVATE_KEY} root@${node}:~/antidote/_build/default/rel/antidote/data/*.tar "${RESULTSSTALEDIR}"
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
  local instances="$1"
  local benchmark_configuration_file="$2"
  local antidote_ip_file="$3"
  local bench_nodes=( $(< ${BENCH_NODEF}) )
  for node in "${bench_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} ./run-benchmark-remote.sh root@${node}:/root/
  done
  export N_INSTANCES="$1"
  export CONFIG_FILE="$2"
  for keyspace in "${KEY_SPACES[@]}"; do
    export KEYSPACE=${keyspace}
    for rounds in "${ROUND_NUMBER[@]}"; do
      export ROUNDS=${rounds}
      local re=0
      for reads in "${READ_NUMBER[@]}"; do
        export UPDATES=${UPDATE_NUMBER[re]}
        export READS=${reads}
        changeBashoBenchConfig
        #NOW RUN A BENCH
        echo "[RunRemoteBenchmark] Running bench with: KEY_SPACES=$KEY_SPACES ROUND_NUMBER=$ROUND_NUMBER READ_NUMBER=$READ_NUMBER UPDATES=$UPDATES"
        ./execute-in-nodes.sh "$(< ${BENCH_NODEF})" \
      "./run-benchmark-remote.sh ${antidote_ip_file} ${instances} ${benchmark_configuration_file}"
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
  local total_dcs="$1"
  local antidote_ip_file=".antidote_ip_file"

  prepareTests ${total_dcs} "${antidote_ip_file}"

  local bench_instances="${BENCH_INSTANCES}"
  local benchmark_configuration_file="${BENCH_FILE}"
  runRemoteBenchmark "${bench_instances}" "${benchmark_configuration_file}" "${antidote_ip_file}"
}

run "$@"
