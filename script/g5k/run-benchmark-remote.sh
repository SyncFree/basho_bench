#!/usr/bin/env bash

set -eo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: ${0##/*} ip-file basho-instances benchmark-configuration-file"
  exit 1
fi

READ_PERCENTAGES=( 99 90 75 50 )
ANTIDOTE_IP_FILE="$1"

changeAntidoteIPs () {
  local config_file="$1"
  local IPS=( $(< ${ANTIDOTE_IP_FILE}) )

  local ips_string
  for ip in "${IPS[@]}"; do
    ips_string+="'${ip}',"
  done
  ips_string=${ips_string%?}

  sed -i.bak "s|^{antidote_pb_ips.*|{antidote_pb_ips, [${ips_string}]}.|g" "${config_file}"
}

changeAntidoteCodePath () {
  local config_file="$1"
  # TODO: Change
  local antidote_code_path="antidote/_build/default/lib/antidote/ebin"

  sed -i.bak "s|^{code_paths.*|{code_paths, [\"${antidote_code_path}\"]}.|g" "${config_file}"
}

changeAntidotePBPort () {
  local config_file="$1"
  # TODO: Change
  local antidote_pb_port=8087
  sed -i.bak "s|^{antidote_pb_port.*|{antidote_pb_port, [${antidote_pb_port}]}.|g" "${config_file}"
}

changeConcurrent () {
  local config_file="$1"
  # TODO: Change
  local concurrent_value=40

  sed -i.bak "s|^{concurrent.*|{concurrent, ${concurrent_value}}.|g" "${config_file}"
}

changeReadWriteRatio () {
  local config_file="$1"
  local ratio="$2"
  local reads="${ratio}"
  local writes=$((100 - ratio))

  sed -i.bak "s|^{num_reads.*|{num_reads, ${reads}}.|g" "${config_file}"
  sed -i.bak "s|^{num_updates.*|{num_updates, ${writes}}.|g" "${config_file}"
}

changeKeyGen () {
  local config_file="$1"
  # TODO: Config
  local keys=100000000
  sed -i.bak "s|^{key_generator.*|{key_generator, {pareto_int, ${keys}}}.|g" "${config_file}"
}

changeOPs () {
  local config_file="$1"
  # TODO: Config
  local ops="[{update_only_txn, 1}]"
  sed -i.bak "s|^{operations.*|{operations, ${ops}}.|g" "${config_file}"
}

changeBashoBenchConfig () {
  local config_file="$1"
  local ratio="$2"

  changeAntidoteIPs "${config_file}"
  # changeAntidoteCodePath "${config_file}"
  changeAntidotePBPort "${config_file}"
  changeConcurrent "${config_file}"

  changeReadWriteRatio "${config_file}" ${ratio}
  changeKeyGen "${config_file}"
}

changeAllConfigs () {
  local n_instances="$1"
  local config_file="$2"
  local read_ratio="$3"
  for i in $(seq 1 ${n_instances}); do
    local bench_folder="basho_bench${i}"
    local config_path="${bench_folder}/examples/${config_file}"

    changeBashoBenchConfig "${config_path}" "${read_ratio}"

    if [[ -d ${bench_folder}/tests ]]; then
      rm -r ${bench_folder}/tests/
    else
      mkdir -p ${bench_folder}/tests/
    fi
  done
}

runAll () {
  local n_instances="$1"
  local config_file="$2"
  for i in $(seq 1 ${n_instances}); do
    local bench_folder="basho_bench${i}"
    local config_path="examples/${config_file}"
    pushd ${bench_folder} > /dev/null 2>&1
    ./_build/default/bin/basho_bench "${config_path}"
    popd
  done
}

collectAll () {
  local n_instances="$1"
  local config_file="$2"
  local ratio="$3"
  local own_node_name="${HOSTNAME::-12}" # remove the .grid5000.fr part of the name
  for i in $(seq 1 ${n_instances}); do
    local bench_folder="./basho_bench${i}"
    pushd "${bench_folder}" > /dev/null 2>&1

    local test_folder="./tests/"
    local result_f_name="test${i}-${own_node_name}-${config_file}-${ratio}.tar"

    tar czf /root/"${result_f_name}" "${test_folder}"
    popd > /dev/null 2>&1
  done
}

run () {
  local n_instances="$1"
  local config_file="$2"

  for ratio in "${READ_PERCENTAGES[@]}"; do
    changeAllConfigs "${n_instances}" "${config_file}" "${ratio}"
    runAll "${n_instances}" "${config_file}"
    collectAll "${n_instances}" "${config_file}" "${ratio}"

    # Wait for the cluster to settle between runs
    sleep 60
  done
}

run "$2" "$3"
