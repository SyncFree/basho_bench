#!/usr/bin/env bash

run () {
  local ip=$(hostname -I | head -1)
  local command="$1"
  ip=${ip%?}

  if [[ "${command}" == "foreground" ]]; then
    INSTANCE_NAME=antidote PB_IP=${ip} IP=${ip} ./antidote/_build/default/rel/antidote/bin/env foreground
  else if [[ "${command}" == "stop" ]]; then
     ./antidote/_build/default/rel/antidote/bin/antidote stop
  else
    echo "wrong command : $command"
  fi
  fi
}

run "$@"
