#!/usr/bin/env bash
# scripts/install.sh
#
# Wrapper de conveniência para rodar o playbook principal, que já executa
# em sequência: bootstrap do RKE2 (role rke2) + instalação do AWX (role awx).
# Todo o deploy do AWX roda dentro da própria VM (ver roles/awx/tasks/main.yml),
# então este script não precisa buscar kubeconfig nem rodar kubectl localmente.
#
# Uso:
#   AWX_HOST_IP=10.190.1.250 SSH_KEY=~/.ssh/awx_ansible ./scripts/install.sh
#
# Pré-requisito (uma vez): ansible-galaxy collection install -r ansible/requirements.yml

set -euo pipefail

: "${AWX_HOST_IP:?Defina AWX_HOST_IP (ex: AWX_HOST_IP=10.190.1.250 ./scripts/install.sh)}"
SSH_KEY="${SSH_KEY:-~/.ssh/awx_ansible}"

echo "=== Rodando playbook: bootstrap do RKE2 + instalação do AWX ==="
ansible-playbook ansible/playbooks/site.yml \
  -e "awx_host_ip=${AWX_HOST_IP}" \
  -e "awx_ssh_key_path=${SSH_KEY}"

echo "=== Instalação concluída ==="
echo "Credenciais do admin exibidas na saída da task 'Exibir credenciais de acesso ao AWX' acima."
echo ""
echo "Para checagens manuais posteriores via kubectl local, use scripts/wait-for-awx-ready.sh"
echo "(requer buscar o kubeconfig da VM antes — ver comentário no próprio script)."