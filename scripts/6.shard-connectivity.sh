#Give your name as kubernetes namespace
namespace='daemonsl'

diskType="k8s-mongodb-"$namespace

# KEEP Config DB size (10-25 GB) very less than Main DB
# Main DB Servers DISK
mainDB_SSD_DISK_inGB="10"

# Config Server DISK
configDB_SSD_DISK_inGB="5"

#--------------------------------------------

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
