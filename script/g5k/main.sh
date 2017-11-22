#!/usr/bin/env bash

set -eo pipefail

IFS=$'\r\n' GLOBIGNORE='*' :;

SELF=$(readlink $0 || true)
if [[ -z ${SELF} ]]; then
  SELF=$0
fi

cd $(dirname "$SELF")

if [[ -z ${CONFIG} ]]; then
  CONFIG=configuration.sh
fi
source $CONFIG

buildReservation () {
  local reservation
  local node_number=$((DCS_PER_SITE * (ANTIDOTE_NODES + BENCH_NODES)))
  for site in "${sites[@]}"; do
    reservation+="${site}:rdef=/nodes=${node_number},"
  done
  # Trim the last (,) in the string
  reservation=${reservation%?}
  echo "${reservation}"
}

reserveSites () {
  local reservation="$(buildReservation)"
  # Outputs something similar to:
  # ...
  # [OAR_GRIDSUB] Grid reservation id = 56670
  # ...
  local res_id=$(oargridsub -t deploy -w '2:00:00' "${reservation}" \
    | grep "Grid reservation id" \
    | cut -f2 -d=)
  # Trim any leading whitespace
  echo "${res_id## }"
}

promptJobCancel() {
  local grid_job="$1"
  local response
  read -r -n 1 -p "Want to cancel reservation? [y/n] " response
  case "${response}" in
    [yY] )
      oargriddel "${grid_job}"
      exit 1 ;;
    *)
      exit 0 ;;
  esac
}


# For each node / ip in a file (one each line),
# ssh into it and run the given command
doForNodesIn () {
   echo "[DOFORNODESIN] executing $2 at nodes : $(cat "$1")"
  ./execute-in-nodes.sh "$(cat "$1")" "$2"
}


# Node Name -> IP
getIPs () {
  [[ -f ${ALL_IPS} ]] && rm ${ALL_IPS}
  [[ -f ${BENCH_IPS} ]] && rm ${BENCH_IPS}
  [[ -f ${ANT_IPS} ]] && rm ${ANT_IPS}

  while read n; do dig +short "${n}"; done < ${ANT_NODES} > ${ANT_IPS}
  while read n; do dig +short "${n}"; done < ${BENCH_NODEF} > ${BENCH_IPS}
  while read n; do dig +short "${n}"; done < ${ALL_NODES} > ${ALL_IPS}
  echo "[GATHER_MACHINES]: ANTIDOTE IPS: ${ANT_IPS}"
  echo "[GATHER_MACHINES]: BENCH IPS: ${BENCH_IPS}"
}

# Get all nodes in reservation, split them into
# antidote and basho bench nodes.
gatherMachines () {
  echo "[GATHER_MACHINES]: Starting..."
  local antidote_nodes_per_site=$((DCS_PER_SITE * ANTIDOTE_NODES))
  local benchmark_nodes_per_site=$((BENCH_NODES))
  [[ -f ${ALL_NODES} ]] && rm ${ALL_NODES}
  [[ -f ${ANT_NODES} ]] && rm ${ANT_NODES}
  [[ -f ${BENCH_NODEF} ]] && rm ${BENCH_NODEF}

  # Remove all blank lines and repeats
  # and add those to the full machine list
  oargridstat -w -l ${GRID_JOB_ID} | sed '/^$/d' \
    | awk '!seen[$0]++' > ${ALL_NODES}

  # For each site, get the list of nodes and slice
  # them into antidote and basho bench lists, depending on
  # the configuration given.
  for site in "${sites[@]}"; do
    awk < ${ALL_NODES} "/${site}/ {print $1}" \
      | tee >(head -${antidote_nodes_per_site} >> ${ANT_NODES}) \
      | sed "1,${antidote_nodes_per_site}d" \
      | head -${benchmark_nodes_per_site} >> ${BENCH_NODEF}
  done

  # Override the full node list, in case we didn't pick all the nodes
  cat ${BENCH_NODEF} ${ANT_NODES} > ${ALL_NODES}

  getIPs

  echo "[GATHER_MACHINES]: Done"
}


# Calculates the number of datacenters in the benchmark
getTotalDCCount () {
  # FIX: Assumes that all sites have the same number of data centers
  local sites_size=${#sites[*]}
  local total_dcs=$(( sites_size * DCS_PER_SITE))
  echo ${total_dcs}
}

# Use kadeploy to provision all the machines
kadeployNodes () {
  for site in "${sites[@]}"; do
    echo -e "\t[SYNC_IMAGE_${sites}]: Starting..."

    local image_dir="$(dirname "${K3_IMAGE}")"
    # rsync can only create dirs up to two levels deep, so we create it just in case
    ssh -o StrictHostKeyChecking=no ${site} "mkdir -p ${image_dir}"
    rsync "${image_dir}"/* ${site}:"${image_dir}"
    rsync -r "${SCRATCHFOLDER}"/* ${site}:"${SCRATCHFOLDER}"

    echo -e "\t[SYNC_IMAGE_${site}]: Done"

    echo -e "\t[DEPLOY_IMAGE_${site}]: Starting..."

    local command="\
      oargridstat -w -l ${GRID_JOB_ID} \
        | sed '/^$/d' \
        | awk '/${site}/ {print $1}' > ~/.todeploy && \
      kadeploy3 -f ~/.todeploy -a ${K3_IMAGE} -k ${EXPERIMENT_PUBLIC_KEY}
    "

    $(
      ssh -t -o StrictHostKeyChecking=no ${site} "${command}" \
        > ${LOGDIR}/${site}-kadeploy-${GLOBAL_TIMESTART} 2>&1
    ) &

    echo -e "\t[DEPLOY_IMAGE_${site}]: In progress"
  done
  echo "[DEPLOY_IMAGE]: Waiting. (This may take a while)"
  wait
}


provisionBench () {
  echo -e "\t[PROVISION_BENCH_NODES]: Starting..."

  for i in $(seq 1 ${BENCH_INSTANCES}); do
    local bench_folder="basho_bench${i}"
    local command="\
      rm -rf ${bench_folder} && \
      git clone ${BENCH_URL} --branch ${BENCH_BRANCH} --single-branch ${bench_folder}
    "

    doForNodesIn ${BENCH_NODEF} "${command}" \
      >> "${LOGDIR}/basho-bench-compile-job-${GLOBAL_TIMESTART}" 2>&1

  done

  echo -e "\t[PROVISION_BENCH_NODES]: Done"
}

cleanBench () {
  echo -e "\t[CLEAN-BENCH]: Starting..."

  for i in $(seq 1 ${BENCH_INSTANCES}); do
    local bench_folder="basho_bench${i}"
    local command="\
      cd ~ && \
      rm -rf *.tar && \
      cd ~/$bench_folder && \
      git stash && \
      git pull && \
      sed -i -e 's/bb@127.0.0.1/bb${i}@127.0.0.1/g' rebar.config && \
      make
    "
    doForNodesIn ${BENCH_NODEF} "${command}" \
      >> "${LOGDIR}/basho-bench-clean-job-${GLOBAL_TIMESTART}" 2>&1

  done

  echo -e "\t[CLEAN-BENCH]: Done"
}


provisionAntidote () {
  echo -e "\t[PROVISION_ANTIDOTE_NODES]: Starting... (This may take a while)"

  local command="\
    rm -rf antidote && \
    git clone ${ANTIDOTE_URL} --branch ${ANTIDOTE_BRANCH} --single-branch antidote"
  # We need antidote in all nodes even if we don't use it
  # basho_bench will need the sources to start
  doForNodesIn ${ALL_NODES} "${command}" \
    >> "${LOGDIR}/antidote-compile-and-config-job-${GLOBAL_TIMESTART}" 2>&1

  echo -e "\t[PROVISION_ANTIDOTE_NODES]: Done"
}


rebuildAntidote () {
  echo -e "\t[REBUILD_ANTIDOTE]: Starting..."
  local command="\
    cd; \
    cd antidote; \
    pkill beam; \
    rm -rf benchLogs; \
    sed -i.bak 's/127.0.0.1/localhost/g' rel/vars/dev_vars.config.src rel/files/app.config; \
    sed -i.bak 's/127.0.0.1/localhost/g' config/vars.config; \
    make relclean; \
    git checkout ${ANTIDOTE_BRANCH}; \
    git pull; \
    ./rebar3 upgrade; \
    sed -i.bak 's|{txn_prot.*},|{txn_prot, $ANTIDOTE_PROTOCOL},|g' src/antidote.app.src && \
    sed -i.bak 's|{stable_strict.*},|{stable_strict, $STRICT_STABLE},|g' src/antidote.app.src && \
    sed -i.bak 's|define(HEARTBEAT_PERIOD.*).|define(HEARTBEAT_PERIOD, ${HBPERIOD}).|g' include/antidote.hrl && \
    sed -i.bak 's|define(VECTORCLOCK_UPDATE_PERIOD.*).|define(VECTORCLOCK_UPDATE_PERIOD, ${HBPERIOD}).|g' include/antidote.hrl && \
    sed -i.bak 's|define(META_DATA_SLEEP.*).|define(META_DATA_SLEEP, ${HBPERIOD}).|g' include/antidote.hrl && \
    make rel
  "
  # We use the IPs here so that we can change the default (127.0.0.1)
  doForNodesIn ${ALL_NODES} "${command}" \
    >> "${LOGDIR}/config-antidote-${GLOBAL_TIMESTART}" 2>&1

  echo -e "\t[REBUILD_ANTIDOTE]: Done"
}


# Git pull changes, make relclean and make rel antidote
cleanAntidote () {
  echo -e "\t[CLEAN_ANTIDOTE]: Starting..."
  local command="\
    cd antidote; \
    pkill beam; \
    git checkout ${ANTIDOTE_BRANCH}; \
    git pull; \
    make relclean; \
    ./rebar3 upgrade; \
    sed -i.bak 's|{txn_prot.*},|{txn_prot, $ANTIDOTE_PROTOCOL},|g' src/antidote.app.src && \
    sed -i.bak 's|{{stable_strict.*},|{stable_strict, $STRICT_STABLE},|g' src/antidote.app.src && \
    sed -i.bak 's|define(HEARTBEAT_PERIOD.*).|define(HEARTBEAT_PERIOD, $HBPERIOD).|g' include/antidote.hrl && \
    sed -i.bak 's|define(VECTORCLOCK_UPDATE_PERIOD.*).|define(VECTORCLOCK_UPDATE_PERIOD, $HBPERIOD).|g' include/antidote.hrl && \
    sed -i.bak 's|define(META_DATA_SLEEP.*).|define(META_DATA_SLEEP, $HBPERIOD).|g' include/antidote.hrl && \
    make rel
  "
  doForNodesIn ${ALL_NODES} "${command}" \
    >> ${LOGDIR}/clean-antidote-${GLOBAL_TIMESTART} 2>&1

  echo -e "\t[CLEAN_ANTIDOTE]: Done"
}

# Provision all the nodes with Antidote and Basho Bench
provisionNodes () {
if [[ "${DOWNLOAD_ANTIDOTE}" == "true" ]]; then
                echo "[DOWNLOAD_ANTIDOTE]: Starting..."
                provisionAntidote
                changeRingSize
                rebuildAntidote
                echo "[DOWNLOAD_ANTIDOTE]: Done"
              else
                changeRingSize
                if [[ "${CLEAN_ANTIDOTE}" == "true" ]]; then
                  echo "[BUILD_ANTIDOTE]: Starting..."
                  rebuildAntidote
                else
                  cleanAntidote
                fi
                echo "[DOWNLOAD_ANTIDOTE]: Skipping, just building"
  fi
            echo "[BUILD_ANTIDOTE]: Done"

if [[ "${DOWNLOAD_BENCH}" == "true" ]]; then
                echo "[DOWNLOAD_BENCH]: Starting..."
                provisionBench
                cleanBench
                echo "[DOWNLOAD_BENCH]: Done"
              else
                    echo "[DOWNLOAD_BENCH]: Skipping, just building"
                      if [[ "${CLEAN_BENCH}" == "true" ]]; then
                echo "[BUILD_BENCH]: Starting..."
                  cleanBench
                  echo "[BUILD_BENCH]: Done"
                fi
              fi
}

# Creates unique erlang cookies for all basho_bench and antidote nodes.
# All nodes of the same type inside the same datacenter hold the same cookie.
createCookies () {
  echo -e "\t[CREATE_COOKIES]: Starting..."

  local total_dcs=$1

  [[ -f ${ALL_COOKIES} ]] && rm ${ALL_COOKIES}
  [[ -f ${ANT_COOKIES} ]] && rm ${ANT_COOKIES}
  [[ -f ${BENCH_COOKIES} ]] && rm ${BENCH_COOKIES}

  for n in $(seq 1 ${total_dcs}); do
    # In each datacenter, all antidote nodes must have the same cookie
    for _ in $(seq 1 ${ANTIDOTE_NODES}); do
      echo "dccookie${n}" | tee -a ${ALL_COOKIES} >> ${ANT_COOKIES}
    done

    # In each datacenter, all basho_bench nodes must have the same cookie
    for _ in $(seq 1 ${BENCH_NODES}); do
      echo "dccookie${n}" | tee -a ${ALL_COOKIES} >> ${BENCH_COOKIES}
    done

  done

  echo -e "\t[CREATE_COOKIES]: Done"
}


# TODO: Really necessary? How do we distribute them?
# Send erlang cookies to the appropiate antidote nodes.
distributeCookies () {
  echo -e "\t[DISTRIBUTE_COOKIES]: Starting..."

  local cookie_array=($(cat ${ALL_COOKIES}))
  local cookie_dev_config="antidote/rel/vars/dev_vars.config.src"
  local cookie_config="antidote/config/vars.config"

  local c=0
  while read node; do
    local cookie=${cookie_array[$c]}
    local command="sed -i.bak 's|^{cookie.*|{cookie, ${cookie}}.|g' ${cookie_config} ${cookie_dev_config}"
    ssh -i ${EXPERIMENT_PRIVATE_KEY} -T \
        -o ConnectTimeout=3 \
        -o StrictHostKeyChecking=no root@${node} "${command}"
    c=$((c + 1))
  done < ${ANT_IPS}

  echo -e "\t[DISTRIBUTE_COOKIES]: Done"
}

transferIPs () {
  local bench_node_file="$1"
  local antidote_ips_file="$2"
  local antidote_ips_file_name=$(basename "${antidote_ips_file}")

  local bench_dc_nodes=( $(< "${bench_node_file}") )
  echo "[DISTRIBUTE NODES FILES ] copying dc files to nodes!!!"
  for node in "${bench_dc_nodes[@]}"; do
    command="scp -i ${EXPERIMENT_PRIVATE_KEY} .dc_nodes* root@${node}:/root/"
    echo "running: $command"
    $command
  done
}

changeRingSize () {
  echo "[CHANGE_RING_SIZE]: Starting..."

  local dc_size=${ANTIDOTE_NODES}
  ./change-partition-size.sh ${dc_size}

  echo "[CHANGE_RING_SIZE]: Done"
}

prepareClusters () {

#  echo "[STOP_ANTIDOTE]: Starting..."
#  ./control-nodes.sh --stop
#  echo "[STOP_ANTIDOTE]: Done"

  echo "[START_ANTIDOTE]: Starting..."
  ./control-nodes.sh --start
  echo "[START_ANTIDOTE]: Done"

    # TODO: Find a better way to do this -> Wait until all the nodes respond to ping?
  sleep 30

if [[ "${CONNECT_CLUSTERS_AND_DCS}" == "true" ]]; then

  local total_dcs="$1"
  local antidote_ip_file="$2"

            createCookies ${total_dcs}
          distributeCookies
  ./prepare-clusters.sh ${ANTIDOTE_NODES} ${total_dcs}

  local ant_offset=0
  local bench_offset=0
  for _ in $(seq 1 ${total_dcs}); do
    head -$((ANTIDOTE_NODES + ant_offset)) "${ANT_IPS}" > "${antidote_ip_file}"
    head -$((BENCH_NODES + bench_offset)) "${BENCH_NODEF}" > .dc_bench_nodes

    ant_offset=$((ant_offset + ANTIDOTE_NODES))
    bench_offset=$((bench_offset + BENCH_NODES))
  done
  # if the cluster was not rebuilt, start background processes in antidote
#  else
#    echo "[ONLY STARTING BG PROCESSES]"
#    startBGprocesses ${total_dcs} >> "${LOGDIR}"/start-bg-dc${GLOBAL_TIMESTART} 2>&1
#    echo "[DONE STARTING BG PROCESSES!]"
  fi
}

runTests () {
  local total_dcs=$(getTotalDCCount)
  echo "[RUNNING_TEST]: Starting..."


  export ANTIDOTE_IP_FILE=".antidote_ip_file"
  command="runRemoteBenchmark ${BENCH_INSTANCES} ${BENCH_FILE} ${ANTIDOTE_IP_FILE} ${total_dcs}"
  echo "running $command"
  $command >> ${LOGDIR}/basho-bench-execution-${GLOBAL_TIMESTART} 2>&1
  echo "[RUNNING_TEST]: Done"

}

collectResults () {
  echo "[COLLECTING_RESULTS]: Starting..."
  [[ -d "${RESULTSDIR}" ]] && rm -r "${RESULTSDIR}"
  mkdir -p "${RESULTSDIR}"
  local bench_nodes=( $(< ${BENCH_NODEF}) )
  for node in "${bench_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} root@${node}:/root/test* "${RESULTSDIR}"
  done

    echo "[COLLECTING_RESULTS]: Done..."
  echo "[DELETING RESULTS FROM NODES]: Starting..."

  doForNodesIn ${BENCH_NODEF} \
  "rm -rf /root/test*"

    echo "[DELETING RESULTS FROM NODES]: DONE..."

}

tarEverything () {
  pushd "${SCRATCHFOLDER}" > /dev/null 2>&1
  local tar_name="$(basename "${SCRATCHFOLDER}")-$GLOBAL_TIMESTART"
  command="tar -czf ../${tar_name}.tar ${SCRATCHFOLDER}"
  $command
#  rm -rf "${SCRATCHFOLDER}"
  popd > /dev/null 2>&1


}
collectStalenessResults(){
echo "[COLLECTING_RESULTS]: Taring antidote staleness logs at all antidote nodes..."
  doForNodesIn ${ANT_NODES} \
  "cd ~/antidote; \
  chmod +x ./bin/physics_staleness/tar-staleness-results-g5k.sh
  ./bin/physics_staleness/tar-staleness-results-g5k.sh -${GLOBAL_TIMESTART}-${ANTIDOTE_PROTOCOL}-${STRICT_STABLE}"

  echo "[COLLECTING_RESULTS]: Done TARING"


  [[ -d "${RESULTSSTALEDIR}" ]] && rm -r "${RESULTSSTALEDIR}"
   mkdir -p "${RESULTSSTALEDIR}"

  echo "[COLLECTING TARED STALENESS RESULTS FROM ANTIDOTE]: ......"
  local antidote_nodes=( $(< ${ANT_NODES}) )
  for node in "${antidote_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} root@${node}:/root/*StalenessResults.tar "${RESULTSSTALEDIR}"
  done
    echo "[COLLECTING TARED STALENESS RESULTS FROM ANTIDOTE]: Done, put them in $RESULTSSTALEDIR......"
}

# Prepare the experiment, create the output folder,
# logs and key pairs.
setupKeys () {
  echo "[SETUP_KEYS]: Starting..."
  mkdir -p ${SCRATCHFOLDER}
  mkdir -p ${LOGDIR}
  cp ${PRKFILE} ${EXPERIMENT_PRIVATE_KEY}
  cp ${PBKFILE} ${EXPERIMENT_PUBLIC_KEY}
  echo "[SETUP_KEYS]: Done"
}


# Gather information about all the deployed machines, like
# node names and IPs, and split them into antidote and basho_bench
# nodes. If selected, it will also go ahead and deploy the k3 image
# into the nodes.
deployImages () {
  gatherMachines
  if [[ "${DEPLOY_IMAGE}" == "true" ]]; then
    echo "[DEPLOY_IMAGE]: Starting..."
    kadeployNodes
    echo "[DEPLOY_IMAGE]: Done"
  else
    echo "[DEPLOY_IMAGE]: Skipping"
  fi
}

syncClocks () {
if [[ "${FORCE_NTP_SYNC}" == "true" ]]; then
    echo "[SYNC CLOCKS]: Starting..."
    ./sync-time.sh --start
    echo "[SYNC CLOCKS]: Done"
    else
        echo "[SYNC CLOCKS]: Disabled"
    fi

}



run () {
  export antidote_ip_file=".antidote_ip_file"

  setupKeys
  if [[ "${JUST_RUN}" == "false" ]]; then

          #get machines and define which are antidote and bench,
          # and deploy images
          if [[ "${IMAGES_LOADED}" == "false" ]]; then
            deployImages
            export IMAGES_LOADED="true"
          fi
          provisionNodes
          local total_dcs=$(getTotalDCCount)
          prepareClusters ${total_dcs} "${antidote_ip_file}"
          transferIPs .dc_bench_nodes "${antidote_ip_file}"
          syncClocks
  fi
  runTests
  collectResults >> ${LOGDIR}/collect-results-${GLOBAL_TIMESTART} 2>&1
  collectStalenessResults >> ${LOGDIR}/collect-staleness-results-${GLOBAL_TIMESTART} 2>&1
  tarEverything
  echo "done collecting staleness results"
}


CopyStalenessLogs () {
  local total_dcs=$1
  local nodes_str=""
    # Get only one antidote node per DC
  for i in $(seq 1 ${total_dcs}); do
    local clusterhead=$(head -1 .dc_nodes${i})
    nodes_str+="'antidote@${clusterhead}' "
  done

  clusterhead=$(head -1 .dc_nodes1)
  nodes_str=${nodes_str%?}

#  local head=$(head -1 .dc_nodes1)

  echo "[SYNCING ANTIDOTE STALENESS LOGS]: SYNCING antidote staleness logs... "
  echo "[SYNCING ANTIDOTE STALENESS LOGS]:executing in node $clusterhead /root/antidote/bin/sync_staleness_logs.erl ${nodes_str}"
  ./execute-in-nodes.sh "$clusterhead" \
        "chmod +x /root/antidote/bin/sync_staleness_logs.erl && \
        /root/antidote/bin/sync_staleness_logs.erl ${nodes_str}"
  echo -e "\t[SYNCING AND CLOSING ANTIDOTE STALENESS LOGS]: Done"


  dirStale="benchLogs/Staleness/Stale-$KEYSPACE-$ROUNDS-$READS-$UPDATES-$BENCH_CLIENTS_PER_INSTANCE"
  dirLog="benchLogs/Log/Log-$KEYSPACE-$ROUNDS-$READS-$UPDATES-$BENCH_CLIENTS_PER_INSTANCE"

  command1="\
    cd ~/antidote && \
    mkdir -p $dirStale && \
    cp _build/default/rel/antidote/data/Staleness* $dirStale && \
    mkdir -p $dirLog && \
    cp _build/default/rel/antidote/log/*.log $dirLog"
  echo "[COPYING STALENESS LOGS]: moving logs to directory: $dirStale at all antidote nodes... "
  echo "[COPYING LOGS]: moving logs to directory: $dirLog at all antidote nodes... "
  echo "\t[GetAntidoteLogs]: executing $command1 at ${antidote_nodes[@]}..."
    doForNodesIn ".antidote_ip_file" "${command1}"
   echo "[COPYING STALENESS LOGS]: done! "

  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]: Truncating antidote staleness logs... "
  echo "[TRUNCATING ANTIDOTE STALENESS LOGS]:executing in node $clusterhead /root/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
  ./execute-in-nodes.sh "$clusterhead" \
        "/root/antidote/bin/truncate_staleness_logs.erl ${nodes_str}"
  echo -e "\t[TRUNCATING ANTIDOTE STALENESS LOGS]: Done"
}

startBGprocesses() {
  local total_dcs=$1
    # Get only one antidote node per DC
  for i in $(seq 1 ${total_dcs}); do
    local clusterhead=$(head -1 .dc_nodes${i})
    nodes_str+="'antidote@${clusterhead}' "
  done
  nodes_str=${nodes_str%?}
#  local head=$(head -1 .dc_nodes1)
  local join_cluster="\
    ./antidote/bin/start_bg_processes.erl ${nodes_str}
  "
  ./execute-in-nodes.sh "${nodes_str}" "${join_cluster}" "-debug"
}

runRemoteBenchmark () {
  firstround=1
# THIS FUNCTION WILL MANY ROUNDS FOR ANTIDOTE:
# ONE FOR EACH KEYSPACE, NUMBER OF ROUNDS, AND READ/UPDATE RATIO.
# In between rounds, it will copy antidote logs to a folder in data, and truncate them.
  local antidote_ip_file="$3"
  local total_dcs="$4"
  local bench_nodes=( $(< ${BENCH_NODEF}) )
  echo "[RUN REMOTE BENCHMARK : ] bench_nodes=${bench_nodes[@]}"
  for node in "${bench_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} ./run-benchmark-remote.sh root@${node}:/root/
  done
  for keyspace in "${KEY_SPACES[@]}"; do
    export KEYSPACE=${keyspace}
    for rounds in "${ROUND_NUMBER[@]}"; do
      export ROUNDS=${rounds}
      local re=0
      for reads in "${READ_NUMBER[@]}"; do
        export UPDATES=${UPDATE_NUMBER[re]}
        export READS=${reads}
        for clients_per_bench_instance in "${BENCH_THREAD_NUMBER[@]}"; do
            export BENCH_CLIENTS_PER_INSTANCE=${clients_per_bench_instance}
            # Wait for the cluster to settle between runs

#            no need to start bg processes as a restart does it itself
#            echo "[STARTING BG PROCESSES]"
#            startBGprocesses ${total_dcs} >> "${LOGDIR}"/start-bg-dc${GLOBAL_TIMESTART} 2>&1
#            echo "[DONE STARTING BG PROCESSES!]"


            #NOW RUN A BENCH
            local benchfilename=$(basename $BENCH_FILE)
            echo "./run-benchmark-remote.sh ${antidote_ip_file} ${BENCH_INSTANCES} ${benchfilename} ${KEYSPACE} ${ROUNDS} ${READS} ${UPDATES} ${ANTIDOTE_NODES} ${BENCH_CLIENTS_PER_INSTANCE} ${total_dcs}"
            ./execute-in-nodes.sh "$(< ${BENCH_NODEF})" \
            "./run-benchmark-remote.sh ${antidote_ip_file} ${BENCH_INSTANCES} ${benchfilename} ${KEYSPACE} ${ROUNDS} ${READS} ${UPDATES} ${ANTIDOTE_NODES} ${BENCH_CLIENTS_PER_INSTANCE} ${total_dcs}"
            sleep 10
                        # yea, that.
            CopyStalenessLogs "${total_dcs}" >> "${LOGDIR}"/copy-staleness-logs-${GLOBAL_TIMESTART} 2>&1
            echo "[RunRemoteBenchmark] done."
        done
        #cleanAntidote
        #local total_dcs=$(getTotalDCCount)
        #prepareClusters ${total_dcs} "${antidote_ip_file}"
        re=$((re+1))
        sleep 10
      done
    done
  done
}

# this flag ensures we download images only once.
export IMAGES_LOADED="false"

for protocol in "${ANTIDOTE_PROTOCOLS[@]}"; do
    export CONFIG_PROTOCOL=${protocol}

    case "${CONFIG_PROTOCOL}" in
        ("cure") export STRICT_STABLE="false" ANTIDOTE_PROTOCOL="clocksi" HBPERIOD="10" ;;
        ("av") export STRICT_STABLE="true" ANTIDOTE_PROTOCOL="clocksi" HBPERIOD="10" ;;
        ("oc") export STRICT_STABLE="true" ANTIDOTE_PROTOCOL="physics" HBPERIOD="10" ;;
        ("ec") export STRICT_STABLE="false" ANTIDOTE_PROTOCOL="ec" HBPERIOD="10" ;;
        ("gr") export STRICT_STABLE="false" ANTIDOTE_PROTOCOL="gr" HBPERIOD="10" ;;
    esac



    export GLOBAL_TIMESTART=$(date +"%Y-%m-%d-%s")
    sites=( "${SITES[@]}" )


    ANTIDOTE_IP_FILE="$1"



    if [[ "${RESERVE_SITES}" == "true" ]]; then
      echo "[RESERVING_SITES]: Starting..."
      export GRID_JOB_ID=$(reserveSites)

      if [[ -z "${GRID_JOB_ID}" ]]; then
        echo "Uh-oh! Something went wrong while reserving. Maybe try again?"
        exit 1
      fi

      sed -i.bak '/^GRID_JOB_ID.*/d' configuration.sh
      echo "GRID_JOB_ID=${GRID_JOB_ID}" >> configuration.sh
      echo "[RESERVING_SITES]: Done. Successfully reserved with id ${GRID_JOB_ID}"
    else
      echo "[RESERVING_SITES]: Skipping"
    fi

    # Delete the reservation if script is killed
    trap 'cancelJob ${GRID_JOB_ID}' SIGINT SIGTERM

    SCRATCHFOLDER="/home/$(whoami)/grid-benchmark-${GRID_JOB_ID}"
    export LOGDIR=${SCRATCHFOLDER}/logs/${GLOBAL_TIMESTART}
    RESULTSDIR=${SCRATCHFOLDER}/results/bench-${GLOBAL_TIMESTART}-${ANTIDOTE_PROTOCOL}-${STRICT_STABLE}
    RESULTSSTALEDIR=${SCRATCHFOLDER}/results-staleness/staleness-${GLOBAL_TIMESTART}-${ANTIDOTE_PROTOCOL}-${STRICT_STABLE}

    export EXPERIMENT_PRIVATE_KEY=${SCRATCHFOLDER}/key
    EXPERIMENT_PUBLIC_KEY=${SCRATCHFOLDER}/exp_key.pub

    export ALL_NODES=${SCRATCHFOLDER}/.all_nodes
    export BENCH_NODEF=${SCRATCHFOLDER}/.bench_nodes
    export ANT_NODES=${SCRATCHFOLDER}/.antidote_nodes

    export ALL_IPS=${SCRATCHFOLDER}/.all_ips
    BENCH_IPS=${SCRATCHFOLDER}/.bench_ips
    export ANT_IPS=${SCRATCHFOLDER}/.antidote_ips

    export ALL_COOKIES=${SCRATCHFOLDER}/.all_cookies
    ANT_COOKIES=${SCRATCHFOLDER}/.antidote_cookies
    BENCH_COOKIES=${SCRATCHFOLDER}/.bench_cookies

    run


  # don't do the following for the next rounds.
#    export DEPLOY_IMAGE="false"
#    export DOWNLOAD_ANTIDOTE="false"
#    export DOWNLOAD_BENCH="false"

done