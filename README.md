# Kubernetes Aggregated Logging

Aggregates [kubernetes](kubernetes.io) container logs into [MongoDB](mongodb.com).

> Shamelessly based on https://github.com/openshift/origin-aggregated-logging

```
+---------------+
| Pod           |
|+------------+ |        +---------+
|| Container1 |---Log--->|         |
|+------------+ |        |         |         +---------+
|               |        | Fluentd |-------->| MongoDB |
|+------------+ |        |         |         +---------+
|| Container2 |---Log--->|         |
|+------------+ |        +---------+
+---------------+

```

Each node of the cluster runs a [Fluentd](fluentd.org) instance to collect container logs and send
to a remote MongoDB. Fluentd runs from a [DaemontSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
so it can spread throughout the cluster.

## Installing on Kubernetes

### Create namespace:

    $ kubectl create namespace kube-logging
    namespace "kube-logging" created

### Deploy:

    $ kubectl -n kube-logging create -f templates/kubernetes-aggregated-logging.yaml
    serviceaccount "logging-fluentd" created
    daemonset "logging-fluentd" created
    service "logging-fluentd-mongodb" created
    persistentvolumeclaim "logging-fluentd-mongodb-data" created
    deployment "logging-fluentd-mongodb" created

After a few moments you can connect to mongodb and list collected logs:

    $ kubectl -n kube-logging get pods
    NAME                                       READY     STATUS    RESTARTS   AGE
    logging-fluentd-f6jdj                      1/1       Running   0          12m
    logging-fluentd-mongodb-2536737460-6w8nh   1/1       Running   4          12m
    logging-fluentd-r53nd                      1/1       Running   0          12m
    
    $ kubectl -n kube-logging exec -it logging-fluentd-mongodb-2536737460-6w8nh sh
    
    sh-4.2$ mongo -u $MONGODB_USER -p $MONGODB_PASSWORD $MONGODB_DATABASE
    
    > db.logs.find().pretty()


## Installing on Openshift

### Create namespace:

    $ oc create namespace kube-logging

### Deploy:

Give `privileged` permissions for service account to mount local node directories into fluentd container:

    # oadm policy add-scc-to-user privileged system:serviceaccount:kube-logging:logging-fluentd

    $ oc process -f templates/openshift-aggregated-logging.yaml | oc -n kube-logging create -f -
    serviceaccount "logging-fluentd" created
    daemonset "logging-fluentd" created
    service "logging-fluentd-mongodb" created
    persistentvolumeclaim "logging-fluentd-mongodb-data" created
    deployment "logging-fluentd-mongodb" created

After a few moments you can connect to mongodb and list collected logs:

    oc rsh -n kube-logging $(oc get pods -n kube-logging -l name=logging-fluentd-mongodb -o name)
    
    sh-4.2$ mongo -u $MONGODB_USER -p $MONGODB_PASSWORD $MONGODB_DATABASE
    
    > db.logs.find().pretty()


## Collecting logs from a set of nodes

By default DaemonSets create pods on all nodes of the cluster (except those marked as NotReady and/or SchedulingDisabled).
It's pretty common to have a separated set of nodes for infrastructure (logging, metrics, router, etc) and another
for "hard work". If that is your case, and you want to collect logs only from "worker" containers, edit the DaemonSet template
and add a `nodeSelector` with proper labels.

For example, given following cluster:

    $ lukbectl get nodes --show-labels
    NAME     STATUS                        AGE      LABELS
    infra0   Ready                         43d      role=infra,zone=us-east1a
    infra1   Ready                         43d      role=infra,zone=us-east1b
    master0  Ready,SchedulingDisabled      43d      role=master,zone=us-east1a
    node0    NotReady,SchedulingDisabled   43d      role=worker,zone=us-east1a     <--- collect only from `role=worker`
    node1    NotReady,SchedulingDisabled   43d      role=worker,zone=us-east1b     <---
    node2    NotReady,SchedulingDisabled   43d      role=worker,zone=us-east1a     <---
    node3    NotReady,SchedulingDisabled   43d      role=worker,zone=us-east1b     <---

In order to collect logs only from nodes with label `role=worker`, edit the DaemonSet (or the template prior to 
deploy) to add the nodeSelector:

    $ kubectl edit ds/logging-fluentd

Insert into `spec.template.spec` the following:

    nodeSelector:
      role: "worker"


## Using external MongoDB

To use an external or already existing MongoDB instance, all you need to do is point the service to another endpoint.
Please refer to [openshift documentation for more
details](https://docs.openshift.org/latest/dev_guide/integrating_external_services.html#saas-define-service-using-ip-address).

> The same is valid for both kubernetes and openshift services.


## Issues

### Deployment fails for MongoDB

Check if Deployment object has the correct apiVersion for your kubernetes release.

For **kubernetes < 1.6** edit `templates/kubernetes-aggregated-logging.yaml` and set `apiVersion=extensions/v1beta1` of object Deployment.

For **openshift < 3.6** edit `templates/openshift-aggregated-logging.yaml` and set `apiVersion=extensions/v1beta1` of object Deployment

### MongoDB can't start

Case mongodb fails to start with errors below, check if PVC has sufficient access permissions

    ERROR: Couldn't write into /var/lib/mongodb/data
    CAUSE: current user doesn't have permissions for writing to /var/lib/mongodb/data directory
    DETAILS: current user id = 184, user groups: 995 0
    stat: failed to get security context of '/var/lib/mongodb/data': No data available
    DETAILS: directory permissions: drwxr-xr-x owned by 0:0, SELinux: ?

On Azure, all it needs is to change permissions directly on the attached disk root:

    node# chmod 777 /var/lib/kubelet/plugins/kubernetes.io/azure-disk/mounts/b39784728

## License

[Apache License, Version 2.0](http://www.apache.org/licenses/)
