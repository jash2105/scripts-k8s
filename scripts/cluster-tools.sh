#!/bin/bash

## Various utility functions used in other scripts

# Function waits until k8s cluster finished updating by fluxcd
# after changes have been made. 
# It checks the cluster in a loop every WAIT number of seconds.
# Default WAIT time is 20 seconds
# $1 - optional WAIT time
wait_for_ready() {
  WAIT=20
  [[ -z "$1" ]] || { WAIT=$1; }
  echo "Waiting for the system to be ready"
  sleep ${WAIT}
  while flux get all -A | grep -q Unknown ; do 
    date 
    echo "System not ready yet, waiting ${WAIT}"
    sleep ${WAIT}
  done
}

# Function prepares git repository structure for services for
# a specific namespace. If the given NAMESPACE is the same as
# DEFAULT_NS, no changes are made as the service is then located
# in default folder.
# $1 - mandatory BASE_DIR where the services' definitions are
#      stored in git repository. Typically this is: 
#      /ABSOLUTE_PATH_TO_CLUSTER_REPO/infra/common
#      or
#      /ABSOLUTE_PATH_TO_CLUSTER_REPO/infra/apps
# $2 - mandatory NAMESPACE for which the strucutre has to be created
# $3 - mandatory DEFAULT_NS
mkdir_ns() {
  # Services for the same namespace are stored in the same folder
  CL="${1}"
  [[ "${2}" == "${3}" ]] || {
    CL="${CL}/${2}"
    mkdir -p ${CL}
  }
  echo ${CL}
}

# Function updates kustomization.yaml in a given folder
# $1 - optional folder where the kustomization has to be updated
#      if no parameter is provided, kustomization is updated in the
#      current folder
update_kustomization() {
  DIR="."
  [[ -z "$1" ]] || { DIR=$1; }
  echo "Update service kustomization for ${DIR} in "`pwd`
  cd ${DIR}
  rm -f kustomization.yaml
  kustomize create --autodetect --recursive
  cd -
}

# Function commits git repository changes and runs flux reconcilation
# $1 - optional parameter is a service name which is added to the
#      commit message
update_repo() {
  git add -A
  git commit -am "${1} deployment"
  git push
  flux reconcile source git "${FLUX_NS}"
}

# Function updates given yaml file to add 'flux-system' namespace
# for the chart source metadata. These scripts store all charts
# sources definition under 'flux-system' namespace but flux, sometimes
# seems to have problems finding them if the namespace in yaml file
# is not provided explicitly. This function solves the problem.
# $1 - mandatory file name to update
update_chart_ns() {
  yq e -i '.spec.chart.spec.sourceRef.namespace = "flux-system"' ${1}
}

# Function which stores some secrets in a file in local filesystem
# for a user to later use them to connect to some services.
# For example k8s dashboard password, longhorn username and password
# and so on. All these kind of login data are dynamically generated
# by scripts using pwgen and stored in the cluster.
# They have to be then provided to the user/admin to allow him to
# connect and login to the services.
# All the secrets are stored in ${HOME}/.kube/k8s-secrets
# $1 - mandatory SECRET_NAME name of the secret stored
# $2 - mandatory SECRET_TOKEN the actual secret stored
update_k8s_secrets() {
  echo -n "${1}: " >> ${HOME}/.kube/k8s-secrets
  echo "${2}" >> ${HOME}/.kube/k8s-secrets
}

# Function generates random and secrure token or password, optionally
# storring the token for a user in local filesystem using 
# `update_k8s_secrets` function.
# $1 - optional token length, if not provided the len is 16
# $2 - optional token name, if provided the token is stored using
#      `update_k8s_secrets` function.
gen_token() {
  len=16
  [[ -z "$1" ]] || { len=$1; }
  t=`pwgen -s ${len} 1`
  [[ -z "$2" ]] || { update_k8s_secrets ${2} ${t}; }
  echo ${t}
}

