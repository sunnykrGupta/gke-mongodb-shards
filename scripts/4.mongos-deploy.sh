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


# Deploy some Mongos Routers using a Kubernetes Deployment
echo "Deploying GKE Deployment & Service for Mongos Routers"

#Change NAMESPACE_ID
sed -e "s/NAMESPACE_ID/${namespace}/g; s/default.svc/${namespace}.svc/g" ../resources/mongodb-mongos-deployment-service.yaml > ../resources/tmp/tmp-mongodb-mongos-deployment-service.yaml
kubectl apply -f ../resources/tmp/tmp-mongodb-mongos-deployment-service.yaml
