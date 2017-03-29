#!/usr/bin/env bash

run () {
  local ip=$(hostname -I | head -1)
  local command="$1"
  ip=${ip%?}

  INSTANCE_NAME=antidote PB_IP=${ip} IP=${ip} ./antidote/_build/default/rel/antidote/bin/env "${command}"
}

run "$@"
