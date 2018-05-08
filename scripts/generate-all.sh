
# Create two Shards each with one replicaset member
# And one config server

#Give your name as kubernetes namespace
namespace='daemonsl'

diskType="k8s-mongodb-"$namespace

# KEEP Config DB size (10-25 GB) very less than Main DB
# Main DB Servers DISK
mainDB_SSD_DISK_inGB="10"

# Config Server DISK
configDB_SSD_DISK_inGB="5"

#-----------------------NAMESPACE creation--------------

echo "Creating namespace : " $namespace

# Replace NAMESPACE_ID with namespace assigned above
sed -e "s/NAMESPACE_ID/${namespace}/g" ../resources/namespace.yaml > ../resources/tmp/tmp-namespace.yaml

#Apply namespace if not exists
kubectl apply -f ../resources/tmp/tmp-namespace.yaml


#----------1 PART------------storageClassName Creation-------

# Define storage class for dynamically generated persistent volumes
kubectl apply -f ../resources/gce-ssd-storageclass.yaml


# Register GCE Fast SSD persistent disks and then create persistent disk in k8s
echo "Creating SSD GCE disks"
for i in 1 2
do
    echo pd-ssd-disk-${diskType}-${mainDB_SSD_DISK_inGB}g-$i
    # Main server db disk
    gcloud compute disks create --size ${mainDB_SSD_DISK_inGB}GB --type pd-ssd pd-ssd-disk-${diskType}-${mainDB_SSD_DISK_inGB}g-$i
done

for i in 1
do
    echo pd-ssd-disk-${diskType}-${configDB_SSD_DISK_inGB}g-$i
    # config server db disk
    gcloud compute disks create --size ${configDB_SSD_DISK_inGB}GB --type pd-ssd pd-ssd-disk-${diskType}-${configDB_SSD_DISK_inGB}g-$i
done
sleep 3



# Create persistent volumes using disks created above
echo "Creating GKE Persistent Volumes Main Server"
for i in 1 2
do
    # Replace text stating volume number + size of disk (mainDB_SSD_DISK_inGB)
    sed -e "s/INSTANCE/${i}/g; s/SIZE/${mainDB_SSD_DISK_inGB}/g; s/TYPE/${diskType}/g" ../resources/ext4-gce-ssd-persistentvolume.yaml > ../resources/tmp/tmp-ext4-gce-ssd-persistentvolume.yaml
    kubectl apply -f ../resources/tmp/tmp-ext4-gce-ssd-persistentvolume.yaml
done

for i in 1
do
    # Replace text stating volume number + size of disk (configDB_SSD_DISK_inGB)
    sed -e "s/INSTANCE/${i}/g; s/SIZE/${configDB_SSD_DISK_inGB}/g; s/TYPE/${diskType}/g" ../resources/ext4-gce-ssd-persistentvolume.yaml > ../resources/tmp/tmp-ext4-gce-ssd-persistentvolume.yaml
    kubectl apply -f ../resources/tmp/tmp-ext4-gce-ssd-persistentvolume.yaml
done
sleep 3

#------2 PART ---------------------------------------------------

# Deploy a MongoDB ConfigDB Service ("Config Server") using a Kubernetes StatefulSet

# CHANGE DISK To dynamic allocation and NAMESPACE_ID
sed -e "s/NAMESPACE_ID/${namespace}/g; s/DB_DISK/${configDB_SSD_DISK_inGB}Gi/g" ../resources/mongodb-configdb-service-stateful.yaml > ../resources/tmp/tmp-mongodb-configdb-service-stateful.yaml

echo "Deploying GKE StatefulSet & Service for MongoDB Config Server"
kubectl apply -f ../resources/tmp/tmp-mongodb-configdb-service-stateful.yaml


#------3 PART ---------------------------------------------------

# Deploy each MongoDB Shard Service using a Kubernetes StatefulSet
echo "Deploying GKE StatefulSet & Service for each MongoDB Shard Replica Set"

#Change Shard Names and DB_DISK, NAMESPACE_ID
echo "Construct Shard1"
sed -e "s/shardX/shard1/g; s/ShardX/Shard1/g; s/NAMESPACE_ID/${namespace}/g; s/DB_DISK/${mainDB_SSD_DISK_inGB}Gi/g" ../resources/mongodb-maindb-service-stateful.yaml > ../resources/tmp/tmp-mongodb-maindb-service-stateful.yaml
kubectl apply -f ../resources/tmp/tmp-mongodb-maindb-service-stateful.yaml

echo "Construct Shard2"
sed -e "s/shardX/shard2/g; s/ShardX/Shard2/g; s/NAMESPACE_ID/${namespace}/g; s/DB_DISK/${mainDB_SSD_DISK_inGB}Gi/g" ../resources/mongodb-maindb-service-stateful.yaml > ../resources/tmp/tmp-mongodb-maindb-service-stateful.yaml
kubectl apply -f ../resources/tmp/tmp-mongodb-maindb-service-stateful.yaml


#------4 PART ---------------------------------------------------

# Deploy some Mongos Routers using a Kubernetes Deployment
echo "Deploying GKE Deployment & Service for Mongos Routers"

#Change NAMESPACE_ID
sed -e "s/NAMESPACE_ID/${namespace}/g; s/default.svc/${namespace}.svc/g" ../resources/mongodb-mongos-deployment-service.yaml > ../resources/tmp/tmp-mongodb-mongos-deployment-service.yaml
kubectl apply -f ../resources/tmp/tmp-mongodb-mongos-deployment-service.yaml

#------5 PART ---------------------------------------------------

# Wait until the final mongod of each Shard + the ConfigDB has started properly
echo
echo "Waiting for all the shards and configdb containers to come up (`date`)..."
echo " (IGNORE any reported not found & connection errors)"

echo -n "  "
echo "mongodb-configdb-0"
until kubectl --v=0 exec --namespace=${namespace} mongodb-configdb-0 -c mongodb-configdb-container -- mongo --port 27019 --quiet --eval 'db.getMongo()'; do
    echo -n "  "
done

echo -n "  "
echo "mongodb-shard1-0"
until kubectl --v=0 exec --namespace=${namespace} mongodb-shard1-0 -c mongodb-shard1-container -- mongo --port 27017 --quiet --eval 'db.getMongo()'; do
    echo -n "  "
done

echo -n "  "
echo "mongodb-shard2-0"
until kubectl --v=0 exec --namespace=${namespace} mongodb-shard2-0 -c mongodb-shard2-container -- mongo --port 27017 --quiet --eval 'db.getMongo()'; do
    echo -n "  "
done

echo -n "  "
echo "...shards & configdb containers are now running (`date`)"
echo


#------6 PART ---------------------------------------------------

# Initialise the Config Server Replica Set and each Shard Replica Set
echo "Configuring Shards' Replica Sets"

echo "Replicaset Init mongodb-shard1-0"
kubectl exec --namespace=${namespace} mongodb-shard1-0 -c mongodb-shard1-container -- mongo --port 27017 --eval "rs.initiate({_id: \"Shard1\", version: 1, members: [ {_id: 0, host: \"mongodb-shard1-0.mongodb-shard1-headless-service.${namespace}.svc.cluster.local:27017\"} ] });"

echo "Replicaset Init mongodb-shard2-0"
kubectl exec --namespace=${namespace} mongodb-shard2-0 -c mongodb-shard2-container -- mongo --port 27017 --eval "rs.initiate({_id: \"Shard2\", version: 1, members: [ {_id: 0, host: \"mongodb-shard2-0.mongodb-shard2-headless-service.${namespace}.svc.cluster.local:27017\"} ] });"

#--------------------------------------------


# Wait for each MongoDB Shard's Replica Set + the ConfigDB Replica Set to each have a primary ready
echo "Waiting for all the MongoDB ConfigDB & Shards' Replica Sets to initialise..."


echo "Checking state : mongodb-configdb-0"
kubectl exec --namespace=${namespace} mongodb-configdb-0 -c mongodb-configdb-container -- mongo --port 27019 --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'

echo "Checking state : mongodb-shard1-0"
kubectl exec --namespace=${namespace} mongodb-shard1-0 -c mongodb-shard1-container -- mongo --port 27017 --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'

echo "Checking state : mongodb-shard2-0"
kubectl exec --namespace=${namespace} mongodb-shard2-0 -c mongodb-shard2-container -- mongo --port 27017 --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'

sleep 2 # Just a little more sleep to ensure everything is ready!
echo "...initialisation of the MongoDB Replica Sets completed"
echo

#Can be added some sleep

# Add Shards to the Configdb
echo "Configuring ConfigDB to be aware of the 2 Shards"

echo "Adding Shard 1 : Shard1 "
kubectl exec --namespace=${namespace} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${namespace} ) -c mongos-container -- mongo --port 27017 --eval "sh.addShard(\"Shard1/mongodb-shard1-0.mongodb-shard1-headless-service.${namespace}.svc.cluster.local:27017\");"

echo "Adding Shard 2 : Shard2 "
kubectl exec --namespace=${namespace} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${namespace} ) -c mongos-container -- mongo --port 27017 --eval "sh.addShard(\"Shard2/mongodb-shard2-0.mongodb-shard2-headless-service.${namespace}.svc.cluster.local:27017\");"

sleep 3

# Add Shards to the Configdb
echo "Enable Sharding in one database"
kubectl exec --namespace=${namespace} $(kubectl get pod -l "tier=routers" -o jsonpath='{.items[0].metadata.name}' --namespace=${namespace} ) -c mongos-container -- mongo --port 27017 --eval "sh.enableSharding(\"dbName\" );"


# Print Summary State
kubectl get persistentvolumes --namespace=${namespace}
echo
kubectl get svc,po,sts --namespace=${namespace}
echo


kubectl get po -l role=mongos --namespace=${namespace}
echo "----------------------------------------"
echo "'" $(kubectl get po -l "role=mongos" -o jsonpath='{.items[0].metadata.name}' --namespace=${namespace}) "'" " - Mongos Service Name to be configured in container running in Kubernetes in namespace:$namespace"
