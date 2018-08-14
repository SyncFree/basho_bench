#!/bin/bash

docker-compose exec antidote1 tc qdisc replace dev eth0 root netem loss 0%

