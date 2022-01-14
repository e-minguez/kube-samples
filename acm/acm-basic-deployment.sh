export NAMESPACE='open-cluster-management'
export OG='acm-operator-group'
export ACMVERSION='release-2.4'

oc create namespace ${NAMESPACE}
oc annotate project ${NAMESPACE} openshift.io/node-selector=''

envsubst <<"EOF" | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${OG}
  namespace: ${NAMESPACE}
spec:
  targetNamespaces:
  - ${NAMESPACE}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: acm-operator-subscription
  namespace: ${NAMESPACE}
spec:
  sourceNamespace: openshift-marketplace
  source: redhat-operators
  channel: ${ACMVERSION}
  installPlanApproval: Automatic
  name: advanced-cluster-management
EOF

until oc wait crd/multiclusterhubs.operator.open-cluster-management.io --for condition=established --timeout 10s >/dev/null 2>&1 ; do sleep 1 ; done

envsubst <<"EOF" | oc apply -f -
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: ${NAMESPACE}
spec: {}
EOF

oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true }}'

export DB_VOLUME_SIZE="10Gi"
export FS_VOLUME_SIZE="10Gi"
export OCP_VERSION="4.9"
export OCP_RELEASE_VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-${OCP_VERSION}/release.txt | awk '/machine-os / { print $2 }')
export ISO_URL="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${OCP_VERSION}/latest/rhcos-${OCP_VERSION}.0-x86_64-live.x86_64.iso"
export ROOT_FS_URL="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${OCP_VERSION}/latest/rhcos-live-rootfs.x86_64.img"



envsubst <<"EOF" | oc apply -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: AgentServiceConfig
metadata:
 name: agent
spec:
  databaseStorage:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: ${DB_VOLUME_SIZE}
  filesystemStorage:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: ${FS_VOLUME_SIZE}
  osImages:
    - openshiftVersion: "${OCP_VERSION}"
      version: "${OCP_RELEASE_VERSION}"
      url: "${ISO_URL}"
      rootFSUrl: "${ROOT_FS_URL}"
      cpuArchitecture: "x86_64"
EOF