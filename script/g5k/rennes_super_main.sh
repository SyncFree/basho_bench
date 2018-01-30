#!/usr/bin/env bash
#i=3
#while [ $i -lt 4 ]
#do
set -eo pipefail


###### facebook
#cp -f ~/basho_bench/script/g5k/configuration-single-dc-facebook-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
#~/basho_bench/script/g5k/main.sh
cp -f ~/basho_bench/script/g5k/configuration-2-dc-facebook-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
#cp -f ~/basho_bench/script/g5k/configuration-3-dc-facebook-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
#~/basho_bench/script/g5k/main.sh


###### first run single round
cp -f ~/basho_bench/script/g5k/configuration-single-dc-single-round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
cp -f ~/basho_bench/script/g5k/configuration-single-dc-single-round-local-2.sh ~/basho_bench/script/g5k/configuration.sh
~/basho_bench/script/g5k/main.sh
#cp -f ~/basho_bench/script/g5k/configuration-2-dc-single-round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
#~/basho_bench/script/g5k/main.sh
#cp -f ~/basho_bench/script/g5k/configuration-3-dc-single-round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
#~/basho_bench/script/g5k/main.sh



###### 5round
#cp -f ~/basho_bench/script/g5k/configuration-single-dc-5round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
#~/basho_bench/script/g5k/main.sh
#cp -f ~/basho_bench/script/g5k/configuration-2-dc-5round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
#~/basho_bench/script/g5k/main.sh
#cp -f ~/basho_bench/script/g5k/configuration-3-dc-5round-local-100r.sh ~/basho_bench/script/g5k/configuration.sh
#~/basho_bench/script/g5k/main.sh
#done