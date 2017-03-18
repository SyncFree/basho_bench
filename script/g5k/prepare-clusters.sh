#!/usr/bin/env bash

run () {
  local dc_size=$1
  local total_dcs=$2
  echo "[restarting antidote to build cluster]: Starting..."

  echo "[BUILD_CLUSTER]: Starting..."
  ./join-clusters.sh ${dc_size} ${total_dcs}
  echo "[BUILD_CLUSTER]: Done"
}

run "$@"
