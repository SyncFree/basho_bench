#!/usr/bin/env bash

set -eo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: ${0##/*} ip-file basho-instances benchmark-configuration-file"
  exit 1
fi


KEY_SPACES=( 10000000 1000000 100000 10000 )
ROUND_NUMBER=( 1 2  10 10 )
READ_NUMBER=( 100 100 90 75 50 )
UPDATE_NUMBER=( 1 2 10 25 50 )
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
  local concurrent_value=200

  sed -i.bak "s|^{concurrent.*|{concurrent, ${concurrent_value}}.|g" "${config_file}"
}

changeReadWriteRatio () {
  local config_file="$1"

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
  changeAntidoteIPs "${config_file}"
#  changeAntidoteCodePath "${config_file}"
#  changeAntidotePBPort "${config_file}"
#  changeConcurrent "${config_file}"

  changeReadWriteRatio "${config_file}"
  changeKeyGen "${config_file}"
}

changeAllConfigs () {
# create a folder for each basho bench instance
  for i in $(seq 1 ${N_INSTANCES}); do
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

# Launch N_INSTANCES of basho bench simultaneoustly
runAll () {
  for i in $(seq 1 ${N_INSTANCES}); do
    local bench_folder="basho_bench${i}"
    local config_path="examples/${CONFIG_FILE}"
    pushd ${bench_folder} > /dev/null 2>&1
    ./_build/default/bin/basho_bench "${config_path}" & export pid_node${i}=$!
    popd
  done
  for i in $(seq 1 ${N_INSTANCES}); do
    while kill -0 ${pid_node${i}}; do
      sleep 1
    done
  done
}

collectAll () {
#  local n_instances="$1"
#  local config_file="$2"
#  local ratio="$3"
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
        runAll
        collectAll

        # Wait for the cluster to settle between runs
        sleep 60
        re=$((re+1))
      done
    done
  done
}

run "$2" "$3"
