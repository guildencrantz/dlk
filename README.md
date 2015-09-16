# Docker Local Kubernetes

# Start Up

    ./dlk.sh

# Shutdown
This is still ugly: Until I script out killing all the containers created by kubernetes I use the nuclear option:

    docker ps | awk '{ print $1; }' | xargs sudo docker kill
