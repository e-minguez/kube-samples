#!/bin/bash
oc create namespace openshift-local-storage
oc annotate project openshift-local-storage openshift.io/node-selector=''
export OC_VERSION=$(oc version -o yaml | grep openshiftVersion | grep -o '[0-9]*[.][0-9]*' | head -1)

envsubst <<"EOF" | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: local-operator-group
  namespace: openshift-local-storage
spec:
  targetNamespaces:
    - openshift-local-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: local-storage-operator
  namespace: openshift-local-storage
spec:
  channel: "${OC_VERSION}"
  installPlanApproval: Automatic 
  name: local-storage-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

until oc wait crd/localvolumes.local.storage.openshift.io --for condition=established --timeout 10s >/dev/null 2>&1 ; do sleep 1 ; done

cat <<EOF| oc apply -f -
apiVersion: "local.storage.openshift.io/v1"
kind: "LocalVolume"
metadata:
  name: "local-disks"
  namespace: "openshift-local-storage" 
spec:
  tolerations:
    - key: node-role.kubernetes.io/master
      operator: Exists
  nodeSelector: 
    nodeSelectorTerms:
    - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - kni1-vmaster-0
          - kni1-vmaster-1
          - kni1-vmaster-2
  storageClassDevices:
    - storageClassName: "local-sc" 
      volumeMode: Filesystem 
      fsType: xfs 
      devicePaths: 
        - /dev/sdb
EOF

until oc get sc/local-sc >/dev/null 2>&1 ; do sleep 1 ; done
oc patch storageclass local-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'