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
