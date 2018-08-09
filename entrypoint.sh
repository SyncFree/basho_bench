#!/bin/bash
case "$1" in
    run)
        shift;
        /opt/basho_bench/basho_bench $@
        ;;
    results)
        echo "Creating summary of last run"
        Rscript --vanilla priv/summary.r -i tests/current
        ;;
    *)
        echo "Usage: bash_bench {run <config-file>|results}"
        exit 1
esac
