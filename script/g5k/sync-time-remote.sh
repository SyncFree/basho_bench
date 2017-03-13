#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
  exit 1
fi

ntpClock () {
  while :
  do
    service ntp stop
    /usr/sbin/ntpdate -b ntp2.grid5000.fr > /dev/null 2>&1
    service ntp start
    sleep 60
  done &
  echo "${!}"
}

start () {
  ntpClock > .ntp_timer_pid
}

stop () {
  if [[ -f .ntp_timer_pid ]]; then
    local timer_pid=$(< .ntp_timer_pid)
    kill ${timer_pid}
  fi
}

case "$1" in
  "--start") start;;
  "*") stop
esac
