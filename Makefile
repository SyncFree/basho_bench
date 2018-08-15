.PHONY: deps

REBAR := ./rebar3

all: deps compile
	${REBAR} escriptize

deps:
	${REBAR} deps

compile: deps
	(${REBAR} compile)

clean:
	${REBAR} clean

runbench:
	_build/default/bin/basho_bench examples/antidote_pb.config

runbench1:
	_build/default/bin/basho_bench examples/antidote_pb_exclusive_locks.config

runbench2:
	_build/default/bin/basho_bench examples/antidote_pb_shared_locks.config

runbench3:
	_build/default/bin/basho_bench examples/antidote_pb_locks_and_shared_locks.config

runbench4:
	_build/default/bin/basho_bench examples/antidote_pb_locks_and_exclusive_locks.config

runbench5:
	_build/default/bin/basho_bench examples/antidote_pb_exclusive_locks_and_shared_locks.config

runbench6:
	_build/default/bin/basho_bench examples/benchmark_locks_read_only.config

runbench7:
	_build/default/bin/basho_bench examples/benchmark_exclusive_locks_read_only.config

runbench8:
	_build/default/bin/basho_bench examples/benchmark_shared_locks_read_only.config

runbench9:
	_build/default/bin/basho_bench examples/benchmark_shared_locks_read_only_incremental.config
	
runbench10:
	_build/default/bin/basho_bench examples/benchmark_exclusive_locks_read_only_incremental.config

runall:
	_build/default/bin/basho_bench examples/antidote_pb_exclusive_locks.config
	_build/default/bin/basho_bench examples/antidote_pb_shared_locks.config
	_build/default/bin/basho_bench examples/antidote_pb_locks_and_shared_locks.config
	_build/default/bin/basho_bench examples/antidote_pb_locks_and_exclusive_locks.config
	_build/default/bin/basho_bench examples/antidote_pb_exclusive_locks_and_shared_locks.config


1_C_E_ReadOnly_Main:
	_build/default/bin/basho_bench simple_benchmarks/1_C_E_ReadOnly_Main.config
10_C_E_ReadOnly_Main:
	_build/default/bin/basho_bench simple_benchmarks/10_C_E_ReadOnly_Main.config
1_C_S_ReadOnly_Main:
	_build/default/bin/basho_bench simple_benchmarks/1_C_S_ReadOnly_Main.config
10_C_S_ReadOnly_Main:
	_build/default/bin/basho_bench simple_benchmarks/10_C_S_ReadOnly_Main.config

1_C_E_ReadOnly_Secondary:
	_build/default/bin/basho_bench simple_benchmarks/1_C_E_ReadOnly_Secondary.config
10_C_E_ReadOnly_Secondary:
	_build/default/bin/basho_bench simple_benchmarks/10_C_E_ReadOnly_Secondary.config
1_C_S_ReadOnly_Secondary:
	_build/default/bin/basho_bench simple_benchmarks/1_C_S_ReadOnly_Secondary.config
10_C_S_ReadOnly_Secondary:
	_build/default/bin/basho_bench simple_benchmarks/10_C_S_ReadOnly_Secondary.config

1_C_E_ReadOnly_Mixed:
	_build/default/bin/basho_bench simple_benchmarks/1_C_E_ReadOnly_Mixed.config
10_C_E_ReadOnly_Mixed:
	_build/default/bin/basho_bench simple_benchmarks/10_C_E_ReadOnly_Mixed.config
1_C_S_ReadOnly_Mixed:
	_build/default/bin/basho_bench simple_benchmarks/1_C_S_ReadOnly_Mixed.config
10_C_S_ReadOnly_Mixed:
	_build/default/bin/basho_bench simple_benchmarks/10_C_S_ReadOnly_Mixed.config


10_C_E_ReadOnly_Mixed_10Min_ViewKeys:
	_build/default/bin/basho_bench lengthy_benchmarks/10_C_E_ReadOnly_Mixed_10Min_ViewKeys.config
10_C_S_ReadOnly_Mixed_10Min_ViewKeys:
	_build/default/bin/basho_bench lengthy_benchmarks/10_C_S_ReadOnly_Mixed_10Min_ViewKeys.config
10_C_ES_ReadOnly_Mixed_10Min_ViewKeys:
	_build/default/bin/basho_bench lengthy_benchmarks/10_C_ES_ReadOnly_Mixed_10Min_ViewKeys.config
10_C_NOLOCKS_ReadOnly_Mixed_10Min_ViewKeys:
	_build/default/bin/basho_bench lengthy_benchmarks/10_C_NOLOCKS_ReadOnly_Mixed_10Min_ViewKeys.config

10_C_E_ReadOnly_Main_10Min_ViewKeys:
	_build/default/bin/basho_bench lengthy_benchmarks/10_C_E_ReadOnly_Main_10Min_ViewKeys.config
10_C_NOLOCKS_ReadOnly_Main_10Min_ViewKeys:
	_build/default/bin/basho_bench lengthy_benchmarks/10_C_NOLOCKS_ReadOnly_Main_10Min_ViewKeys.config


10_C_ES_ReadOnly_Mixed_Pareto_10k_90_%:
	_build/default/bin/basho_bench workload_simulations/10_C_ES_ReadOnly_Mixed_Pareto_10k_90_%.config
10_C_ES_ReadOnly_Mixed_Pareto_100k_90_%:
	_build/default/bin/basho_bench workload_simulations/10_C_ES_ReadOnly_Mixed_Pareto_100k_90_%.config
100_C_ES_ReadOnly_Mixed_Pareto_10k_90_%:
	_build/default/bin/basho_bench workload_simulations/100_C_ES_ReadOnly_Mixed_Pareto_10k_90_%.config
100_C_ES_ReadOnly_Mixed_Pareto_10k_99_9%:
	_build/default/bin/basho_bench workload_simulations/100_C_ES_ReadOnly_Mixed_Pareto_10k_99_9%.config


results:
	Rscript --vanilla priv/summary.r -i tests/current

byte_sec-results:
	Rscript --vanilla priv/summary.r --ylabel1stgraph byte/sec -i tests/current

kbyte_sec-results:
	Rscript --vanilla priv/summary.r --ylabel1stgraph Kbyte/sec -i tests/current

mbyte_sec-results:
	Rscript --vanilla priv/summary.r --ylabel1stgraph Mbyte/sec -i tests/current

TARGETS := $(shell ls tests/ | grep -v current)
JOBS := $(addprefix job,${TARGETS})
.PHONY: all_results ${JOBS}

all_results: ${JOBS} ; echo "$@ successfully generated."
${JOBS}: job%: ; Rscript --vanilla priv/summary.r -i tests/$*
