#!/bin/bash

set -e

pushd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null

docker-compose up -d

echo -n "Waiting for API (this is slow) "
  while [ 1 ]
  do
    sleep 1
    if curl -m1 http://10.0.0.1/api/v1beta3/namespaces/default/pods >/dev/null 2>&1
    then
      break
    fi
  done
echo -e "\e[32mOK\e[39m"

echo -n "Starting skydns  "
  kubectl create -f kube-dns.rc.yaml >/dev/null
  kubectl create -f kube-dns.service.yaml >/dev/null
echo -e "\e[32mOK\e[39m"

echo -n "Verifying skydns "
  while [ 1 ]
  do
    sleep 1
    if nslookup google.com 10.0.0.10 >/dev/null 2>&1
    then
      break
    fi
  done
echo -e "\e[32mOK\e[39m"

popd >/dev/null
