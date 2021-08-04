cat<<EOF| oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: custom-namespace
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-openshift
  namespace: custom-namespace
  labels:
    app: hello-openshift
spec:
  replicas: 1000
  selector:
    matchLabels:
      app: hello-openshift
  template:
    metadata:
      labels:
        app: hello-openshift
    spec:
      containers:
      - name: hello-openshift
        image: quay.io/openshift/origin-hello-openshift
        ports:
        - containerPort: 8080
EOF
