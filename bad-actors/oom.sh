export HOSTNAME="worker-0.redhat.com"
export NAMESPACE="oom-test"
export IMAGE="registry.redhat.io/rhel7:latest"

cat <<'EOF' > ./oom-test.yaml.template
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  annotations:
    openshift.io/node-selector: "kubernetes.io/hostname=${HOSTNAME}"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: badmem
  namespace: ${NAMESPACE}
  labels:
    app: badmem
spec:
  replicas: 1
  selector:
    matchLabels:
      app: badmem
  template:
    metadata:
      labels:
        app: badmem
    spec:
      containers:
      - args:
        - python
        - -c
        - |
          x = []
          while True:
            x.append("x" * 1048576)
        image: ${IMAGE}
        name: badmem
EOF

envsubst '$HOSTNAME $NAMESPACE ${IMAGE}' < ./oom-test.yaml.template > ./oom-test.yaml

oc apply -f ./oom-test.yaml

# If you want to make things fast
# oc scale -n ${NAMESPACE} deployment/badmem --replicas=100
