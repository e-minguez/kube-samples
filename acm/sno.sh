# Enable this to be able to create hosts in different namespaces than the metal3 one
oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true }}'

# Enable using the external network to serve the virtual media
oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"virtualMediaViaExternalNetwork": true}}'

# Enable assisted service

export DB_VOLUME_SIZE="10Gi"
export FS_VOLUME_SIZE="10Gi"
export OCP_VERSION="4.9"
export ARCH="x86_64"
export OCP_RELEASE_VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/${ARCH}/clients/ocp/latest-${OCP_VERSION}/release.txt | awk '/machine-os / { print $2 }')
export ISO_URL="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${OCP_VERSION}/latest/rhcos-${OCP_VERSION}.0-${ARCH}-live.${ARCH}.iso"
export ROOT_FS_URL="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/${OCP_VERSION}/latest/rhcos-live-rootfs.${ARCH}.img"

until oc get crd/agentserviceconfigs.agent-install.openshift.io >/dev/null 2>&1 ; do sleep 1 ; done


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
      cpuArchitecture: "${ARCH}"
EOF


# Create Spoke cluster, SNO

export SPOKE_SNO_NS="sno1"
export SPOKE_SNO_NAME="sno1"
export LOCATION="westford"
export BASEDOMAIN="sno1.krnl.es"
export PULL_SECRET_CONTENT=$(cat ~/clusterconfigs/pull-secret.txt)
export SSH_PUB=$(cat ~/.ssh/id_rsa.pub)
export PULL_SECRET_NAME="pull-secret-${SPOKE_SNO_NAME}"
export DOMAIN="krnl.es"
export BMC_USERNAME=$(echo -n "root" | base64 -w0)
export BMC_PASSWORD=$(echo -n "password" | base64 -w0)
export BMC_IP="10.19.143.29"
export IMAGESET="img4.9.13-x86-64-appsub"
export BOOT_MAC_ADDRESS="xx:xx:xx:xx:xx:xx"
export HARDWARE_PROFILE="dell-raid"
export MACHINE_NETWORK_CIDR="10.19.138.0/24"
export SERVICE_NETWORK_CIDR="172.30.0.0/16"
export CLUSTER_NETWORK="10.128.0.0/14"
export CLUSTER_NETWORK_HOST_PREFIX="23"

# Namespace to host all that stuff
envsubst <<"EOF" | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${SPOKE_SNO_NS}
EOF

# Pull secret in 'dockerconfig' format
export PS64=$(echo -n ${PULL_SECRET_CONTENT} | base64 -w0)
envsubst <<"EOF" | oc apply -f -
apiVersion: v1
data:
  .dockerconfigjson: ${PS64}
kind: Secret
metadata:
  name: ${PULL_SECRET_NAME}
  namespace: ${SPOKE_SNO_NS}
type: kubernetes.io/dockerconfigjson
EOF

# Infraenv describes the discovery image
envsubst <<"EOF" | oc apply -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
  labels:
    agentclusterinstalls.extensions.hive.openshift.io/location: ${LOCATION}
    networkType: dhcp
  name: ${SPOKE_SNO_NAME}
  namespace: ${SPOKE_SNO_NS}
spec:
  clusterRef:
    name: ${SPOKE_SNO_NAME}
    namespace: ${SPOKE_SNO_NS}
  pullSecretRef:
    name: ${PULL_SECRET_NAME}
  sshAuthorizedKey: ${SSH_PUB}
EOF

# The clusterdeployment and agentclusterinstall describes the cluster
# there are crossreferences in both
envsubst <<"EOF" | oc apply -f -
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: ${SPOKE_SNO_NAME}
  namespace: ${SPOKE_SNO_NS}
spec:
  baseDomain: ${DOMAIN}
  clusterInstallRef:
    group: extensions.hive.openshift.io
    kind: AgentClusterInstall
    name: ${SPOKE_SNO_NAME}
    version: v1beta1
  clusterName: ${SPOKE_SNO_NAME}
  controlPlaneConfig:
    servingCertificates: {}
  installed: false
  platform:
    agentBareMetal:
      agentSelector:
        matchLabels:
          cluster-name: ${SPOKE_SNO_NAME}
  pullSecretRef:
    name: ${PULL_SECRET_NAME}
EOF

envsubst <<"EOF" | oc apply -f -
apiVersion: extensions.hive.openshift.io/v1beta1
kind: AgentClusterInstall
metadata:
  name: ${SPOKE_SNO_NAME}
  namespace: ${SPOKE_SNO_NS}
annotations:
  agent-install.openshift.io/install-config-overrides: '{"networking":{"networkType":"OVNKubernetes"}}'
spec:
  clusterDeploymentRef:
    name: ${SPOKE_SNO_NAME}
  imageSetRef:
    name: ${IMAGESET}
  networking:
    clusterNetwork:
    - cidr: ${CLUSTER_NETWORK}
      hostPrefix: ${CLUSTER_NETWORK_HOST_PREFIX}
    serviceNetwork:
    - ${SERVICE_NETWORK_CIDR}
    machineNetwork:
    - cidr: ${MACHINE_NETWORK_CIDR}
  provisionRequirements:
    controlPlaneAgents: 1
  sshPublicKey: ${SSH_PUB}
EOF

envsubst <<"EOF" | oc apply -f -
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: ${SPOKE_SNO_NAME}
  namespace: ${SPOKE_SNO_NS}
spec:
  clusterName: ${SPOKE_SNO_NAME}
  clusterNamespace: ${SPOKE_SNO_NS}
  clusterLabels:
    cloud: auto-detect
    vendor: auto-detect
  workManager:
    enabled: true
  applicationManager:
    enabled: true
  certPolicyController:
    enabled: false
  iamPolicyController:
    enabled: false
  policyController:
    enabled: true
  searchCollector:
    enabled: false
EOF

# This creates the cluster at RHACM level
envsubst <<"EOF" | oc apply -f -
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: ${SPOKE_SNO_NAME}
  namespace: ${SPOKE_SNO_NS}
spec:
  hubAcceptsClient: true
EOF

envsubst <<"EOF" | oc apply -f -
apiVersion: v1
data:
  password: ${BMC_PASSWORD}
  username: ${BMC_USERNAME}
kind: Secret
metadata:
  name: ${SPOKE_SNO_NAME}-bmc-secret
  namespace: ${SPOKE_SNO_NAME}
type: Opaque
EOF

# The label references the infraenv for a complete SNO workflow
# Inspection is not needed as it would be done by the assisted installer instead
envsubst <<"EOF" | oc apply -f -
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: ${SPOKE_SNO_NAME}
  namespace: ${SPOKE_SNO_NS}
  labels:
    infraenvs.agent-install.openshift.io: ${SPOKE_SNO_NAME}
  annotations:
    inspect.metal3.io: disabled
    bmac.agent-install.openshift.io/role: "master"
spec:
  automatedCleaningMode: disabled
  bmc:
    disableCertificateVerification: True
    address: idrac-virtualmedia+https://${BMC_IP}/redfish/v1/Systems/System.Embedded.1
    credentialsName: ${SPOKE_SNO_NAME}-bmc-secret
  bootMACAddress: ${BOOT_MAC_ADDRESS}
  hardwareProfile: ${HARDWARE_PROFILE}
  online: true
EOF
