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
  local config_file="$1"
  echo "Rounds = ${ROUNDS}"
  echo "READS = ${READS}"
  echo "UPDATES = ${UPDATES}"
  sed -i.bak "s|^{num_read_rounds.*|{num_read_rounds, ${ROUNDS}}.|g" "${config_file}"
  sed -i.bak "s|^{num_reads.*|{num_reads, ${READS}}.|g" "${config_file}"
  sed -i.bak "s|^{num_updates.*|{num_updates, ${UPDATES}}.|g" "${config_file}"
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
  local config_file="$1"
  changeAntidoteIPs "${CONFIG_FILE}"
#  changeAntidoteCodePath "${config_file}"
#  changeAntidotePBPort "${config_file}"
#  changeConcurrent "${config_file}"
  changeReadWriteRatio "${CONFIG_FILE}"
  changeKeyGen "${CONFIG_FILE}"
}

runRemoteBenchmark () {
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
        changeAllConfigs
        #NOW RUN A BENCH
        echo "[RunRemoteBenchmark] Running bench with: KEY_SPACES=$KEY_SPACES ROUND_NUMBER=$ROUND_NUMBER READ_NUMBER=$READ_NUMBER UPDATES=$UPDATES"
        ./execute-in-nodes.sh "$(< ${BENCH_NODEF})" \
      "./run-benchmark-remote.sh ${antidote_ip_file} ${instances} ${benchmark_configuration_file}"
        echo "[RunRemoteBenchmark] done."
        echo "[RunRemoteBenchmark] Collecting staleness logs from antidote."
        ./execute-in-nodes.sh "$(< ${ANT_NODES})" \
      "./run-benchmark-remote.sh ${antidote_ip_file} ${instances} ${benchmark_configuration_file}"


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
