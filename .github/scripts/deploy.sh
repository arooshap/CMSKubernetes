#!/bin/bash

helm repo add stable https://charts.helm.sh/stable
helm plugin install https://github.com/chartmuseum/helm-push
helm repo add --username=${CERN_LOGIN} --password=${CERN_TOKEN} myrepo  https://registry.cern.ch/chartrepo/cmsweb
helm repo update
helm repo list
cd helm
for chart in $(ls -d */Chart.yaml | xargs dirname); do
# echo $chart
          LOCAL_VERSION=$(grep -R "version:" ${chart}/Chart.yaml | awk '{print $2}')
          if ! REMOTE_LATEST_VERSION="$(helm search repo myrepo/"${chart}" | grep myrepo/"${chart}" | awk '{print $2}')" ; then
              echo "INFO There are no remote versions."
              REMOTE_LATEST_VERSION=""
          fi
          if [ "${REMOTE_LATEST_VERSION}" = "" ] || \
              [ "$(expr "${REMOTE_LATEST_VERSION}" \< "${LOCAL_VERSION}")" -eq 1 ]; then
              helm dep update ${chart}
              helm package ${chart}
	      set +x
              helm push --username=${CERN_LOGIN} --password=${CERN_TOKEN} "${chart}-${LOCAL_VERSION}.tgz"  myrepo
              set -x
          fi
done
