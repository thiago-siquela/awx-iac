#!/usr/bin/env bash
# scripts/wait-for-awx-ready.sh
#
# UTILITÁRIO MANUAL/OPCIONAL — a espera principal já acontece dentro da
# role Ansible "awx" (ver ansible/roles/awx/tasks/main.yml), rodando local
# na VM. Use este script apenas para checagens manuais a partir da sua
# máquina, depois de buscar o kubeconfig da VM, ex:
#
#   scp -i ~/.ssh/awx_ansible ansible-svc@IP_DA_VM:/etc/rancher/rke2/rke2.yaml ./kubeconfig
#   sed -i.bak "s/127.0.0.1/IP_DA_VM/g" ./kubeconfig
#   export KUBECONFIG=$(pwd)/kubeconfig
#   ./scripts/wait-for-awx-ready.sh
#
# Aguarda o AWX ficar totalmente disponível verificando o status dos pods.

set -euo pipefail

NAMESPACE="${AWX_NAMESPACE:-awx}"
AWX_NAME="${AWX_NAME:-awx}"
TIMEOUT="${AWX_WAIT_TIMEOUT:-600}"   # segundos
INTERVAL=10
ELAPSED=0

echo ">> Aguardando o AWX '${AWX_NAME}' ficar pronto no namespace '${NAMESPACE}' (timeout: ${TIMEOUT}s)..."

while true; do
  # Verifica se todos os deployments do namespace awx estão com réplicas prontas
  NOT_READY=$(kubectl get deployments -n "${NAMESPACE}" \
    -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.readyReplicas}{"/"}{.spec.replicas}{"\n"}{end}' \
    | awk '{split($2,a,"/"); if (a[1] != a[2] || a[1] == "") print $1}')

  if [ -z "${NOT_READY}" ]; then
    echo ">> Todos os deployments estão prontos."
    break
  fi

  if [ "${ELAPSED}" -ge "${TIMEOUT}" ]; then
    echo "!! Timeout de ${TIMEOUT}s atingido. Deployments ainda não prontos:"
    echo "${NOT_READY}"
    kubectl get pods -n "${NAMESPACE}"
    exit 1
  fi

  echo "   ainda aguardando: ${NOT_READY} (${ELAPSED}s/${TIMEOUT}s)"
  sleep "${INTERVAL}"
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo ">> Verificando resposta da API do AWX..."
NODE_PORT=$(kubectl get svc -n "${NAMESPACE}" "${AWX_NAME}-service" -o jsonpath='{.spec.ports[0].nodePort}')

echo ">> AWX pronto. Serviço exposto na NodePort: ${NODE_PORT}"
echo ">> Teste manual: curl -sk http://<IP_DA_VM>:${NODE_PORT}/api/v2/ping/"