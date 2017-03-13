#!/usr/bin/env bash

# TODO
# There should be read and update latencies, as well as a summary

READ_PERCENTAGES=( 99 90 75 50 )

processPercentage () {
  local percentage="$1"

  local analysis_files=( "summary.csv" "update-only-txn_latencies.csv" )
  local percentage_files=( $(find . -type f -name "*${percentage}.tar"}) )

  local -A file_mapping=()
  mkdir -p summary-${percentage}
  for file in "${percentage_files[@]}"; do
    local dir_name="${file%.*}"
    mkdir -p "${dir_name}"
    tar -C "${dir_name}" -zzf "${file}"
    local analysis_folder=$( ls -l "${dir_name}"/tests/current | awk -F "/" '{print $NF}' )
    for analysis_file in "${analysis_files[@]}"; do
      file_mapping["${analysis_file}"]+="${dir_name}/tests/${analysis_folder}/${analysis_file} "
    done
  done

  # TODO: Don't hardcode this
  for key in "${!file_mapping[@]}"; do
    local awk_script=../basho_bench/script/mergeResults.awk
    if [[ "$key" == "summary.csv" ]]; then
      awk_script=../basho_bench/script/mergeResultsSummary.awk
    fi
    awk -f "${awk_script}" "${file_mapping[$key]}" > summary-${percentage}
  done
}

run () {
  local test_directory="$1"
  local latency_files=( "summary.csv" "update-only-txn_latencies.csv" )

  pushd "${test_directory}" > /dev/null 2>&1

  for percentage in "${READ_PERCENTAGES[@]}"; do
    processPercentage "${percentage}"
  done

  popd > /dev/null 2>&1
}

run "$@"
