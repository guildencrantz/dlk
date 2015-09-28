#!/bin/bash
# vim: set ts=2 sw=2 sts=2 ai et :

set -e

pushd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null

function up {
  docker-compose up -d

  echo -n "Waiting for API "
    while [ 1 ]; do
      sleep 1
      ! kubectl version >/dev/null 2>&1 || break
    done
  echo -e "\e[32mOK\e[39m"

  echo -n "Starting skydns  "
  {
    echo "apiVersion: v1
data:
  kubeconfig: $( cat dns/kubeconfig/kubeconfig.yml | base64 -w 0 )
kind: Secret
metadata:
  name: token-system-dns
type: Opaque
" | kubectl --namespace="kube-system" create -f - >/dev/null 2>&1

    local -r ESCAPED_DIR=$(pwd | sed 's/\//\\\//g')
    sed -e "s/{{DNS_KUBECONFIG}}/$ESCAPED_DIR\/dns\/kubeconfig/" dns/dns.rc.template.yml |
      kubectl create -f - >/dev/null
    kubectl create -f dns/dns.service.yml >/dev/null
  }
  echo -e "\e[32mOK\e[39m"

  echo -n "Verifying skydns (wait for it) "
    timeout 5m bash -c "
      while [ 1 ]; do
        sleep 1
        if nslookup kubernetes.local 10.0.0.10 >/dev/null 2>&1; then
          break
        fi
      done
    "
  echo -e "\e[32mOK\e[39m"

  echo -n "Starting kube-ui  "
    kubectl create -f ui/kube-ui-rc.yaml >/dev/null
    kubectl create -f ui/kube-ui-svc.yaml >/dev/null
  echo -e "\e[32mOK\e[39m"

  echo -n "Starting ElasticSearch for cluster logging  "
    kubectl create -f logging/es-controller.yaml >/dev/null
    kubectl create -f logging/es-service.yaml >/dev/null
  echo -e "\e[32mOK\e[39m"
  echo -n "Starting Kibana for cluster logging  "
    kubectl create -f logging/kibana-controller.yaml >/dev/null
    kubectl create -f logging/kibana-service.yaml >/dev/null
  echo -e "\e[32mOK\e[39m"

  kubectl cluster-info
}

function down {
  for entity in rc svc; do
    entities=$( kubectl get $entity --all-namespaces -o json |
      jq -r '.items[] | .metadata.name + " --namespace=" + .metadata.namespace'
    ) 2>/dev/null

    echo "stop $entity"
    if [ "$entities" != "" ]; then
      while read -r line; do
        echo $line | xargs kubectl stop $entity
      done <<< "$entities"
    fi
  done

  echo "dc stop"
  docker-compose stop

  stragglers=$(curl-unix-socket unix:///var/run/docker.sock:/containers/json |
    jq -r '.[]|select(.Names[]|startswith("/k8s_"))|.Id'
  )

  echo "stop stragglers"
  if [ "$stragglers" != "" ]; then
    while read -r id; do
      echo $id | xargs docker stop
    done <<< "$stragglers"
  fi
}

function help {
  echo "$0 [up|down|bounce]"
}

case $1 in
  up|start) up
    ;;
  down|stop) down
    ;;
  bounce|restart)
    down
    up
    ;;
  *)
    help
    exit 1
    ;;
esac

popd >/dev/null
