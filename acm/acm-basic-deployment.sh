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
