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

runRemoteBenchmark () {
  local instances="$1"
  local benchmark_configuration_file="$2"
  local antidote_ip_file="$3"

  local bench_nodes=( $(< ${BENCH_NODEF}) )
  for node in "${bench_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} ./run-benchmark-remote.sh root@${node}:/root/
  done

  ./execute-in-nodes.sh "$(< ${BENCH_NODEF})" \
      "./run-benchmark-remote.sh ${antidote_ip_file} ${instances} ${benchmark_configuration_file}"
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
