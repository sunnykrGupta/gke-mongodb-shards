
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


#----------------------storageClassName Creation------------------

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
