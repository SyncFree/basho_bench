#!/usr/bin/env bash

set -eo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: ${0##/*} ip-file basho-instances benchmark-configuration-file"
  exit 1
fi

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
    local bench_folder="basho_bench${i}"
    local config_path="${bench_folder}/examples/${CONFIG_FILE}"
    echo "[changeAllConfigs] changing config for basho_bench${i}"
    echo "[changeAllConfigs] config_path = ${config_path}"
#    changeBashoBenchConfig "${config_path}"

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
    ./_build/default/bin/basho_bench "${config_path}" & "pid_node${i}=$!"

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

  export N_INSTANCES="$1"
  export CONFIG_FILE="$2"
#  for keyspace in "${KEY_SPACES[@]}"; do
#    export KEYSPACE=${keyspace}
#    for rounds in "${ROUND_NUMBER[@]}"; do
#      export ROUNDS=${rounds}
#      local re=0
#      for reads in "${READ_NUMBER[@]}"; do
#        export UPDATES=${UPDATE_NUMBER[re]}
#        export READS=${reads}
        changeAllConfigs
        runAll
        collectAll

        # Wait for the cluster to settle between runs
#        sleep 60
#        re=$((re+1))
#      done
#    done
#  done
}

run "$2" "$3"
