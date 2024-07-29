#!/bin/bash
#
# Scripts adds helm sources to the git repo for fluxcd for all common
# services being installed on the cluster
#

source ~/envs/cluster.env || { echo "No cluster.env file"; exit 1; }
source ~/envs/versions.env || { echo "No versions.env file"; exit 1; }

cd ${CLUSTER_REPO_DIR} &> /dev/null || { echo "No cluster repo dir!"; exit 1; }

SOURCES=(
	"${SS_S_NAME}:${SS_URL}"
	"${IN_S_NAME}:${IN_URL}"
	"${LH_S_NAME}:${LH_URL}"
	"${CM_S_NAME}:${CM_URL}"
	"${PM_S_NAME}:${PM_URL}"
	"${LO_S_NAME}:${LO_URL}"
	"${VE_S_NAME}:${VE_URL}"
	"${DA_S_NAME}:${DA_URL}"
	)

add_source() {
  name=${1%%:*}
  url=${1#*:}
  echo "Adding ${name} source at ${url}"
  ${SCRIPTS}/flux-create-source.sh ${name} ${url}
  git add -A
  git commit -am "Added ${name} source"
}


echo -e "\n\n   Adding common sources"

for src in "${SOURCES[@]}" ; do
  add_source ${src}
done

git push
flux reconcile source git flux-system

