#!/bin/bash
# 
# Script deploys Prometheus monitoring to the k8s cluster with grafana
# admin passworf encrypted using sealed secrets.
# If run with '-q' parameter, password is autogenerated using pwgen
# otherwise the script asks to enter admin password from commandline
#

source ~/envs/cluster.env || exit 1
source ~/envs/versions.env || exit 1
source ${SCRIPTS}/cluster-tools.sh || exit 1

NAME="${PM_NAME}"
TNS=${PM_TARGET_NAMESPACE}
SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-${CLUSTER_NAME}.pem"
GRAFANA_ADMIN_PASSWORD=`gen_token 32`
[[ "$1" == "-q" ]] || {
  echo -n "Provide grafana password: "; read gr_adm_pass
  [[ -z ${gr_adm_pass} ]] || GRAFANA_ADMIN_PASSWORD==${gr_adm_pass}
}

cd ${CLUSTER_REPO_DIR}

CL_DIR=`mkdir_ns ${BASE_DIR} ${TNS} ${FLUX_NS}`

mkdir -p "${CL_DIR}/${NAME}"
kubectl create secret generic "prometheus-stack-credentials" \
    --namespace "${PM_TARGET_NAMESPACE}" \
    --from-literal=grafana_admin_password="${GRAFANA_ADMIN_PASSWORD}" \
    --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
    --format=yaml > "${CL_DIR}/${NAME}/prometheus-stack-credentials-sealed.yaml"

echo "Deploying ${NAME}"
~/scripts/flux-create-helmrel.sh \
        "${PM_NAME}" \
        "${PM_VER}" \
        "${PM_RNAME}" \
        "${PM_TARGET_NAMESPACE}" \
        "${PM_NAMESPACE}" \
        "${PM_SOURCE}" \
        "${PM_VALUES}" --create-target-namespace --depends-on="${FLUX_NS}/${SS_NAME}" || exit 1

update_chart_ns "${CL_DIR}/${NAME}/${NAME}.yaml"

cat >> "${CL_DIR}/${NAME}/${NAME}.yaml" <<EOF
  valuesFrom:
    - kind: Secret
      name: prometheus-stack-credentials
      valuesKey: grafana_admin_password
      targetPath: grafana.adminPassword
      optional: false
EOF

#exit 0

update_repo "${NAME}"
