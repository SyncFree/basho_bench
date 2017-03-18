#!/usr/bin/env bash

run () {
  local dc_size=$1
  local total_dcs=$2
  echo "[restarting antidote to build cluster]: Starting..."

  # TODO: Find a better way to do this -> Wait until all the nodes respond to ping?
  sleep 30

  echo "[BUILD_CLUSTER]: Starting..."
  ./join-clusters.sh ${dc_size} ${total_dcs}
  echo "[BUILD_CLUSTER]: Done"
}

run "$@"
