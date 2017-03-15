#!/usr/bin/env bash

set -eo pipefail

#if [[ $# -ne 7 ]]; then
#  echo "Usage: ${0##/*} ip-file basho-instances benchmark-configuration-file keyspace rounds reads updates"
#  exit 1
#fi

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
  local concurrent_value=200

  sed -i.bak "s|^{concurrent.*|{concurrent, ${concurrent_value}}.|g" "${config_file}"
}

changeAllConfigs () {
# create a folder for each basho bench instance
  for i in $(seq 1 ${N_INSTANCES}); do
    echo "[changeAllConfigs] changing config for basho_bench${i}"
    echo "[changeAllConfigs] config_path = ${CONFIG_FILE}"
    local bench_folder="basho_bench${i}"
    local config_path="${bench_folder}/examples/${CONFIG_FILE}"
   changeBashoBenchConfig "${config_path}"

    if [[ -d ${bench_folder}/tests ]]; then
      rm -r ${bench_folder}/tests/
    else
      mkdir -p ${bench_folder}/tests/
    fi
  done
}

changeReadWriteRatio () {
  echo "[changeReadWriteRatio] Changing config files to send to nodes..."
  local config_path="$1"
  echo "Rounds = ${ROUNDS}"
  echo "READS = ${READS}"
  echo "UPDATES = ${UPDATES}"
  sed -i.bak "s|^{num_read_rounds.*|{num_read_rounds, ${ROUNDS}}.|g" "${config_path}"
  sed -i.bak "s|^{num_reads.*|{num_reads, ${READS}}.|g" "${config_path}"
  sed -i.bak "s|^{num_updates.*|{num_updates, ${UPDATES}}.|g" "${config_path}"
}

changeAntidoteIPs () {
  local config_path="$1"
  local IPS=( $(< ${ANTIDOTE_IP_FILE}) )

  local ips_string
  for ip in "${IPS[@]}"; do
    ips_string+="'${ip}',"
  done
  ips_string=${ips_string%?}

  echo "Changing antidote ipsAntidote IPS: ${ips_string}"

  sed -i.bak "s|^{antidote_pb_ips.*|{antidote_pb_ips, [${ips_string}]}.|g" "${config_path}"
}

changeKeyGen () {
  local config_path="$1"
  sed -i.bak "s|^{key_generator.*|{key_generator, {pareto_int, ${KEYSPACE}}}.|g" "${config_path}"
}

changeOPs () {
  local config_path="$1"
  # TODO: Config
  local ops="[{update_only_txn, 1}]"
  sed -i.bak "s|^{operations.*|{operations, ${ops}}.|g" "${config_path}"
}

changeBashoBenchConfig () {
  local config_path="$1"
  changeAntidoteIPs "${config_path}"
#  changeAntidoteCodePath "${config_path}"
#  changeAntidotePBPort "${config_path}"
#  changeConcurrent "${config_path}"
  changeReadWriteRatio "${config_path}"
  changeKeyGen "${config_path}"
}

# Launch N_INSTANCES of basho bench simultaneoustly
runAll () {
  for i in $(seq 1 ${N_INSTANCES}); do
    local bench_folder="basho_bench${i}"
    local config_path="examples/${CONFIG_FILE}"
    pushd ${bench_folder} > /dev/null 2>&1
    ./_build/default/bin/basho_bench "${config_path}" & export "pid_node${i}"=$!

    echo "[RUNALL] ./_build/default/bin/basho_bench ${config_path}"
    echo "[RUNALL]  got pid: $pid_node${i}"
    popd
  done
  echo "[RUNALL] waiting for bench processes to finish..."
  for i in $(seq 1 ${N_INSTANCES}); do
    while kill -0 $pid_node${i}; do
      sleep 1
    done
  done
  echo "[RUNALL] done!"

}

collectAll () {
  local own_node_name="${HOSTNAME::-12}" # remove the .grid5000.fr part of the name
  for i in $(seq 1 ${N_INSTANCES}); do
    local bench_folder="./basho_bench${i}"
    pushd "${bench_folder}" > /dev/null 2>&1
    local test_folder="./tests/"
    local result_f_name="test${i}-${own_node_name}-${CONFIG_FILE}-${KEYSPACE}-${ROUNDS}-${READS}.tar"
    tar czf /root/"${result_f_name}" "${test_folder}"
    popd > /dev/null 2>&1
  done
}

run () {
#this run will run once for every keyspace,
# round number and read number.
# Writes will be used for reads, complementary,
# and do not generate extra rounds
  echo "[run-benchmark-remote] got ANTIDOTE_IPS=$1
  N_INSTANCES=$2
  CONFIG_FILE=$3
  KEYSPACE=$4
  ROUNDS=$5
  READS=$6
  UPDATES=$7"

  export ANTIDOTE_IPS="$1"
  export N_INSTANCES="$2"
  export CONFIG_FILE="$3"
  export KEYSPACE="$4"
  export ROUNDS="$5"
  export READS="$6"
  export UPDATES="$7"

        changeAllConfigs
        runAll
        collectAll
}

run "$@"
