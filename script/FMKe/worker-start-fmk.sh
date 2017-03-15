#!/usr/bin/env bash
# Call this like IP=1.2.3.4 worker-start-antidote.sh

# This is only necessary when running on OS X, erlang 19
# might be removed, but won't harm otherwise...
PATH="$PATH:/opt/local/lib/erlang/erts-8.1/bin/"
chmod +x ~/basho_bench//script/FMKe/*
chmod +x ~/FMKe/bin/*
chmod +x ~/antidote/bin/*

if [ -z "$CleanMake" ]; then
    CleanMake=TRUE
fi
if [ -z "$GitBranch" ]; then
    GitBranch="master"
fi

echo "----Worker $IP ----: cd ~/kerl_dir"
cd ~/kerl_dir
echo "----Worker $IP ----: . ./r18b03/activate"
. ./r18b03/activate

echo "----Worker $IP ----: cd ~/FMKe/"
cd ~/FMKe/
if [ CleanMake=TRUE ]; then

    echo "----Worker $IP ----: git checkout $GitBranch"
    git checkout $GitBranch
    echo "----Worker $IP ----: git pull"
    git pull
    echo "----Worker $IP ----: make relclean"
    make relclean
    echo "----Worker $IP ----: make rel"
    make rel
fi
echo "----Worker $IP ----: IP=$IP ANTIDOTE_ADDRESS=$IP IP=$IP INSTANCE_NAME=fmk ./_build/default/rel/fmk/bin/env foreground"
ANTIDOTE_ADDRESS=$IP IP=$IP INSTANCE_NAME=fmk ./_build/default/rel/fmk/bin/env start &
