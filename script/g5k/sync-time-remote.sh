#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
  exit 1
fi

ntpClock () {
service ntp stop
  for i in 1 2 3
  do
    /usr/sbin/ntpdate -b ntp2.grid5000.fr
  done
  service ntp start
}

start () {
  ntpClock
}

case "$1" in
  "--start") start;;
esac
