#!/bin/bash

set -e

pushd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null

docker-compose up -d

echo -n "Waiting for API "
  while [ 1 ]
  do
    sleep 1
    ! kubectl version >/dev/null || break
  done
echo -e "\e[32mOK\e[39m"

echo -n "Starting skydns  "
  kubectl create -f kube-dns.rc.yaml >/dev/null
  kubectl create -f kube-dns.service.yaml >/dev/null
echo -e "\e[32mOK\e[39m"

echo -n "Verifying skydns (wait for it) "
  while [ 1 ]; do
    sleep 1
    if nslookup google.com 10.0.0.10 >/dev/null 2>&1
    then
      break
    fi
  done
echo -e "\e[32mOK\e[39m"

popd >/dev/null
