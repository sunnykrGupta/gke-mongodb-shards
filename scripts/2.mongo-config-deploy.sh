

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

#---------------------------------------------


# Deploy a MongoDB ConfigDB Service ("Config Server") using a Kubernetes StatefulSet

# CHANGE DISK To dynamic allocation and NAMESPACE_ID
sed -e "s/NAMESPACE_ID/${namespace}/g; s/DB_DISK/${configDB_SSD_DISK_inGB}Gi/g" ../resources/mongodb-configdb-service-stateful.yaml > ../resources/tmp/tmp-mongodb-configdb-service-stateful.yaml

echo "Deploying GKE StatefulSet & Service for MongoDB Config Server"
kubectl apply -f ../resources/tmp/tmp-mongodb-configdb-service-stateful.yaml
