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

#----------------------------------------------


# Deploy each MongoDB Shard Service using a Kubernetes StatefulSet
echo "Deploying GKE StatefulSet & Service for each MongoDB Shard Replica Set"

#Change Shard Names and DB_DISK, NAMESPACE_ID
echo "Construct Shard1"
sed -e "s/shardX/shard1/g; s/ShardX/Shard1/g; s/NAMESPACE_ID/${namespace}/g; s/DB_DISK/${mainDB_SSD_DISK_inGB}Gi/g" ../resources/mongodb-maindb-service-stateful.yaml > ../resources/tmp/tmp-mongodb-maindb-service-stateful.yaml
kubectl apply -f ../resources/tmp/tmp-mongodb-maindb-service-stateful.yaml

echo "Construct Shard2"
sed -e "s/shardX/shard2/g; s/ShardX/Shard2/g; s/NAMESPACE_ID/${namespace}/g; s/DB_DISK/${mainDB_SSD_DISK_inGB}Gi/g" ../resources/mongodb-maindb-service-stateful.yaml > ../resources/tmp/tmp-mongodb-maindb-service-stateful.yaml
kubectl apply -f ../resources/tmp/tmp-mongodb-maindb-service-stateful.yaml
