# First create all namespaces and apps so there is enough time for the apps to be up before tweaking the probes
for i in {0..100}; do
  oc new-project amq${i}
  oc -n amq${i} new-app amq63-basic --name=amq${i}
done

for i in {0..100}; do
  # this is needed to avoid overwhelming the api, otherwise there are oc errors
  sleep 1
  # I decided to use cat /dev/random instead a sleep from the BZ to have some 'workload'
  oc exec -n amq${i} $(oc get pod -o name -l application=broker -n amq${i}) -- sh -c 'echo "cat /dev/random" > /opt/amq/bin/readinessProbe.sh'
done
