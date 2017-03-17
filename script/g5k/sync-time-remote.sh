#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
  exit 1
fi

ntpClock () {
  for i in 1 2 3
  do
    service ntp stop
    /usr/sbin/ntpdate -b ntp2.grid5000.fr
    service ntp start
  done
}

start () {
  ntpClock
}

case "$1" in
  "--start") start;;
esac
