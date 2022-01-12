export NAMESPACE='openshift-operators'
export NAME='openshift-gitops-operator'
export VERSION='v1.3.2'
CRD="gitopsservices.pipelines.openshift.io"

envsubst <<"EOF" | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${NAME}
  namespace: ${NAMESPACE}
spec:
  channel: stable
  installPlanApproval: Automatic
  name: ${NAME}
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: openshift-gitops-operator.${VERSION}
EOF

until oc wait crd/${CRD} --for condition=established --timeout 600s >/dev/null 2>&1 ; do sleep 1 ; done
