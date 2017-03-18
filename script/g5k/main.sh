#!/usr/bin/env bash

set -eo pipefail

IFS=$'\r\n' GLOBIGNORE='*' :;

SELF=$(readlink $0 || true)
if [[ -z ${SELF} ]]; then
  SELF=$0
fi

if [[ -z ${CONFIG} ]]; then
  CONFIG=configuration.sh
fi

cd $(dirname "$SELF")

source $CONFIG
export GLOBAL_TIMESTART=$(date +"%Y-%m-%d-%s")
sites=( "${SITES[@]}" )


ANTIDOTE_IP_FILE="$1"

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
RESULTSDIR=${SCRATCHFOLDER}/results/bench-${GLOBAL_TIMESTART}-${ANTIDOTE_BRANCH}
RESULTSSTALEDIR=${SCRATCHFOLDER}/results-staleness/staleness-${GLOBAL_TIMESTART}-${ANTIDOTE_BRANCH}

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
      cd ~/$bench_folder && \
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
    git clone ${ANTIDOTE_URL} --branch ${ANTIDOTE_BRANCH} --single-branch antidote && \
    cd ~/antidote && \
    make rel
  "
  # We need antidote in all nodes even if we don't use it
  # basho_bench will need the sources to start
  doForNodesIn ${ALL_NODES} "${command}" \
    >> "${LOGDIR}/antidote-compile-and-config-job-${GLOBAL_TIMESTART}" 2>&1

  echo -e "\t[PROVISION_ANTIDOTE_NODES]: Done"
}


rebuildAntidote () {
  echo -e "\t[REBUILD_ANTIDOTE]: Starting..."
  local command="\
    cd antidote; \
    pkill beam; \
    sed -i.bak 's/127.0.0.1/localhost/g' rel/vars/dev_vars.config.src rel/files/app.config; \
    sed -i.bak 's/127.0.0.1/localhost/g' config/vars.config; \
    rm -rf ./_build; \
    git pull; ./rebar3 upgrade; make rel
  "
  # We use the IPs here so that we can change the default (127.0.0.1)
  doForNodesIn ${ALL_NODES} "${command}" \
    >> "${LOGDIR}/config-antidote-${GLOBAL_TIMESTART}" 2>&1

  echo -e "\t[REBUILD_ANTIDOTE]: Done"
}

cleanAntidote () {
  echo -e "\t[CLEAN_ANTIDOTE]: Starting..."

  local command="\
    cd antidote; \
    pkill beam; \
    git pull; \
    make relclean; \
    ./rebar3 upgrade; \
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
  for node in "${bench_dc_nodes[@]}"; do
    scp -i ${EXPERIMENT_PRIVATE_KEY} "${antidote_ips_file}" root@${node}:/root/${antidote_ips_file_name}
  done
}

changeRingSize () {
  echo "[SETUP_TESTS]: Starting..."

  local dc_size=${ANTIDOTE_NODES}
  ./change-partition-size.sh ${dc_size}

  echo "[SETUP_TESTS]: Done"
}

prepareClusters () {

  echo "[STOP_ANTIDOTE]: Starting..."
  ./control-nodes.sh --stop
  echo "[STOP_ANTIDOTE]: Done"

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

    transferIPs .dc_bench_nodes "${antidote_ip_file}"

    ant_offset=$((ant_offset + ANTIDOTE_NODES))
    bench_offset=$((bench_offset + BENCH_NODES))
  done
  # if the cluster was not rebuilt, start background processes in antidote
  else
    echo "[ONLY STARTING BG PROCESSES]"
    startBGprocesses ${total_dcs} >> "${LOGDIR}"/start-bg-dc${GLOBAL_TIMESTART} 2>&1
    echo "[DONE STARTING BG PROCESSES!]"
  fi
}

startBGprocesses() {
  local total_dcs=$1

    # Get only one antidote node per DC
  for i in $(seq 1 ${total_dcs}); do
    local clusterhead=$(head -1 .dc_nodes${i})
    nodes_str+="'antidote@${clusterhead}' "
  done

  nodes_str=${nodes_str%?}

  local head=$(head -1 .dc_nodes1)

  local join_cluster="\
    ./antidote/bin/start_bg_processes.erl ${nodes_str}
  "
  ./execute-in-nodes.sh "${head}" "${join_cluster}" "-debug"
}

runTests () {
  local total_dcs=$(getTotalDCCount)
  echo "[RUNNING_TEST]: Starting..."
  ./run-benchmark.sh ${total_dcs} >> ${LOGDIR}/basho-bench-execution-${GLOBAL_TIMESTART} 2>&1
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
  echo "[COLLECTING_BENCH_RESULTS]: Done"
#  echo "[MERGING_RESULTS]: Starting..."
#  ./merge-results.sh "${RESULTSDIR}"
#  echo "[MERGING_RESULTS]: Done"

}

tarEverything () {
  pushd "${SCRATCHFOLDER}" > /dev/null 2>&1
  local tar_name=$(basename "${RESULTSDIR}")
  tar -czf ../"${tar_name}".tar ${SCRATCHFOLDER}
  rm -rf results
  rm -rf logs
  rm -rf staleness
  popd > /dev/null 2>&1


}
collectStalenessResults(){
echo "[COLLECTING_RESULTS]: Taring antidote staleness logs at all antidote nodes..."
  doForNodesIn ${ANT_NODES} \
  "cd ~/antidote; \
  chmod +x ./bin/physics_staleness/tar-staleness-results-g5k.sh
  ./bin/physics_staleness/tar-staleness-results-g5k.sh -${GLOBAL_TIMESTART}-${ANTIDOTE_BRANCH}"

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

tarLogs () {
  pushd "${LOGDIR}" > /dev/null 2>&1
  local tar_name=$(basename "${LOGDIR}")
  tar -czf ../"${tar_name}".tar ${SCRATCHFOLDER}
  popd > /dev/null 2>&1

}

run () {
  local antidote_ip_file=".antidote_ip_file"
  setupKeys
          #get machines and define which are antidote and bench,
          # and deploy images
          deployImages
          provisionNodes
          local total_dcs=$(getTotalDCCount)
          prepareClusters ${total_dcs} "${antidote_ip_file}"

  syncClocks
  runTests
  collectResults >> ${LOGDIR}/collect-results-${GLOBAL_TIMESTART} 2>&1
  collectStalenessResults >> ${LOGDIR}/collect-staleness-results-${GLOBAL_TIMESTART} 2>&1
  tarLogs
  echo "done collecting staleness results"
}

run
