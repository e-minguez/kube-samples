export IRONIC_USER=$((oc -n openshift-machine-api  get secret/metal3-ironic-password -o template --template '{{.data.username}}' || echo "") | base64 -d)
export IRONIC_PASSWORD=$((oc -n openshift-machine-api  get secret/metal3-ironic-password -o template --template '{{.data.password}}' || echo "") | base64 -d)
export IRONIC_CREDS="$IRONIC_USER:$IRONIC_PASSWORD"
export INSPECTOR_USER=$((oc -n openshift-machine-api  get secret/metal3-ironic-inspector-password -o template --template '{{.data.username}}' || echo "") | base64 -d)
export INSPECTOR_PASSWORD=$((oc -n openshift-machine-api  get secret/metal3-ironic-inspector-password -o template --template '{{.data.password}}' || echo "") | base64 -d)
export INSPECTOR_CREDS="$INSPECTOR_USER:$INSPECTOR_PASSWORD"
export CLUSTER_IRONIC_IP=$(oc get pods -n openshift-machine-api -l baremetal.openshift.io/cluster-baremetal-operator=metal3-state -o jsonpath="{.items[0].status.hostIP}" || echo "")


envsubst <<"EOF" > clouds.yaml
clouds:
  metal3:
    auth_type: http_basic
    auth:
      username: ${IRONIC_USER}
      password: ${IRONIC_PASSWORD}
    baremetal_endpoint_override: ${CLUSTER_IRONIC_IP}
    verify: false
  metal3-inspector:
    auth_type: http_basic
    auth:
      username: ${INSPECTOR_USER}
      password: ${INSPECTOR_PASSWORD}
    baremetal_introspection_endpoint_override: ${CLUSTER_IRONIC_IP}
    verify: false
EOF