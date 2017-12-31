# MongoDB Sharded Cluster Deployment Demo for Kubernetes on GKE


An example project demonstrating the deployment of a MongoDB Sharded Cluster via Kubernetes on the Google Kubernetes Engine (GKE), using Kubernetes' feature StatefulSet. Contains example Kubernetes YAML resource files (in the 'resources' folder) and associated Kubernetes based Bash scripts (in the 'scripts' folder) to configure the environment and deploy a MongoDB Replica Set.

For further background information on what these scripts and resource files do, plus general information about running MongoDB with Kubernetes.

### Must read below resources in order :

- https://kubernetes.io/docs/concepts/workloads/controllers/statefulset
- https://kubernetes.io/docs/concepts/services-networking/service/#headless-services
- https://kubernetes.io/docs/concepts/storage/storage-classes/#gce
- https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- http://blog.kubernetes.io/2017/03/dynamic-provisioning-and-storage-classes-kubernetes.html
- http://blog.kubernetes.io/2017/03/advanced-scheduling-in-kubernetes.html


## 1 How To Run

### 1.1 Prerequisites

Ensure the following dependencies are already fulfilled on your host Linux system:

GCP’s client command line tool [gcloud](https://cloud.google.com/sdk/docs/quickstarts) has been installed on your local workstation.

Your local workstation has been initialised to:
    
1. gcloud authentication to a project to manage container engine.
2. Install the Kubernetes command tool (“kubectl”),
3. Configure authentication credentials,
4. Docker needs to be installed to build an image 


### 1.2 Deployment

#### Configure scripts before running

```
#Give your name as kubernetes namespace where you want to deploy
namespace='daemonsl'

diskType="k8s-mongodb-"$namespace

# KEEP Config DB size (10-25 GB) very less than Main DB
# Main DB Servers DISK
mainDB_SSD_DISK_inGB="10"

# Config Server DISK
configDB_SSD_DISK_inGB="5"
```

After configuring you can proceed to run all scripts.

Using a command-line terminal/shell, execute the following

    $ cd scripts
    $ ./generate-all.sh #to run all 1-7 script combined.

        OR configure each scripts one by one but configure above configuration in each shell script and run each script one-by-one.
    $ sh `1 to 7 scripts one-by-one`.sh

### Scripts Working

1. pd-ssd-create-disks-persistent-vol-creation.sh  #script to create disk to be used by mongodb-replica server and mongo-config database and to create PersistentVolume to reserve disk in retain policy.
2. mongo-config-deploy.sh  #deploy a stateful container, headless-service and register a persistent-volumes-claim to claim disk declared by persistent-volumes.
3. mongo-shard-deploy.sh   #deploy a two shard each in stateful container, headless-service and register a persistent-volumes-claim to claim disk declared by persistent-volumes.
4. mongos-deploy.sh    #deploy mongos as deployment and headless-service to allow all pods for inter-communication.
5. check-pod-status.sh     #to check all pods are up and alive.
6. shard-connectivity.sh   #to configure mongodb-maindb servers to initiate replicasets and configure mongos to enable sharding.

This takes a few minutes to complete. Once completed, you should have a MongoDB Sharded Cluster initialised and running in some Kubernetes StatefulSets/Deployments. The executed bash script will have created the following resources:

* 1x Config Server  (k8s deployment type: "StatefulSet")
* 2x Shards with each Shard being a Replica Set containing 1x replicas (k8s deployment type: "StatefulSet")
* 2x Mongos Routers (k8s deployment type: "Deployment")

You can view the list of Pods that contain these MongoDB resources, by running the following:

    $ kubectl get pods --namespace=NAMESPACE_ID

You can also view the the state of the deployed environment via the [Google Cloud Platform Console](https://console.cloud.google.com) (look at both the “Kubernetes Engine” and the “Compute Engine” sections of the Console).

### 1.3 Test Sharding Your Own Collection

To test that the sharded cluster is working properly, connect to the container running the first "mongos" router, then use the Mongo Shell to authenticate, enable sharding on a specific collection, add some test data to this collection and then view the status of the Sharded cluster and collection:

    $ kubectl exec -it $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}') -c mongos-container bash
    $ mongo
    > sh.enableSharding("dbName");
    > sh.status();

### 1.4 Undeploying & Cleaning Down the Kubernetes Environment

**Important:** This step is required to ensure you aren't continuously charged by Google Cloud for an environment you no longer need.

Run the following script to undeploy the MongoDB Services & StatefulSets/Deployments plus related Kubernetes resources, followed by the removal of the GCE disks. This script is available in repository.

    $ sh teardown.sh   #To delete all resources provisioned above

It is also worth checking in the [Google Cloud Platform Console](https://console.cloud.google.com), to ensure all resources have been removed correctly.


## 2 Factors Addressed By This Project

* Deployment of a MongoDB on the Google Kubernetes Engine
* Use of Kubernetes StatefulSets and PersistentVolumeClaims to ensure data is not lost when containers are recycled
* Proper configuration of a MongoDB Sharded Cluster for Scalability with each Shard being a Replica Set for full resiliency
* Controlling Anti-Affinity for Mongod Replicas to avoid a Single Point of Failure
