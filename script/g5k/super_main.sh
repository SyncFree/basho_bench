#!/usr/bin/env bash

set -eo pipefail
###### first run single round
mv -f ~/basho_bench/script/g5k/configuration-single-dc-single-round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
mv -f ~/basho_bench/script/g5k/configuration-2-dc-single-round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
mv -f ~/basho_bench/script/g5k/configuration-3-dc-single-round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
###### facebook
mv -f ~/basho_bench/script/g5k/configuration-single-dc-facebook-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
mv -f ~/basho_bench/script/g5k/configuration-2-dc-facebook-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
mv -f ~/basho_bench/script/g5k/configuration-3-dc-facebook-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
###### 5round
mv -f ~/basho_bench/script/g5k/configuration-single-dc-5round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
mv -f ~/basho_bench/script/g5k/configuration-2-dc-5round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
mv -f ~/basho_bench/script/g5k/configuration-3-dc-5round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
