# awx-iac 🗼

Infraestrutura como código para provisionamento e instalação do AWX (Ansible Tower) via awx-operator em cluster RKE2.

> **Status:** em construção. Este repositório substitui a instalação legada (`utpapsvlaawx001`), que não está mais em uso.

---

## Visão geral

Este repositório automatiza a instalação do AWX em uma VM já provisionada, cobrindo:

1. Bootstrap do cluster Kubernetes (RKE2) via Ansible
2. Deploy do awx-operator via Kustomize
3. Aplicação do Custom Resource do AWX

A infraestrutura da VM (IaC de provisionamento) **não** está neste repositório — ela é de responsabilidade do IaC da Vitru. Este repositório assume que a VM já existe e está acessível via SSH.

---

## Estrutura do repositório

```
awx-iac/
├── ansible.cfg                  # Configuração do Ansible (precisa ficar na raiz: é
│                                 # daqui que os comandos/CI são invocados)
├── ansible/
│   ├── inventory/                # Inventário (host da VM, variáveis de conexão)
│   ├── playbooks/                 # Playbook principal (site.yml)
│   ├── requirements.yml           # Collections necessárias (ansible.posix)
│   └── roles/
│       ├── rke2/                  # Bootstrap do cluster RKE2
│       └── awx/                   # Deploy do awx-operator + Custom Resource do AWX
├── kubernetes/
│   └── awx/
│       └── base/                  # Kustomization do awx-operator + CR do AWX
├── scripts/                       # install.sh (wrapper do playbook) e utilitários
├── .github/
│   └── workflows/                 # Pipeline CI/CD (lint/validação implementados;
│                                   # deploy automatizado em runner self-hosted em andamento)
└── docs/                          # Documentação complementar
```

_(`execution-environments/` e overlays por ambiente em `kubernetes/awx/overlays/` ainda não existem — serão adicionados quando houver necessidade real de EE customizada ou de diferenciar ambientes)_

---

## Pré-requisitos na VM

Este repositório assume que a VM já existe (provisionamento é responsabilidade do IaC da Vitru — ver [Visão geral](#visão-geral)), mas ela precisa ter, antes da primeira execução: um usuário de serviço com sudo sem senha, e a chave pública SSH desse usuário autorizada. Nenhum desses dois passos é feito pelo Ansible deste repositório — são pré-condição pra ele conseguir rodar.

### 1. Usuário `ansible-svc`

O Ansible se conecta como esse usuário (nome padrão; configurável via `awx_ansible_user`, ver [ansible/inventory/hosts.yml](ansible/inventory/hosts.yml)) e usa `become` (sudo) em praticamente todas as tasks — instalar o RKE2, habilitar o serviço `rke2-server`, ajustar permissões do kubeconfig, etc. Como o [ansible.cfg](ansible.cfg) define `become_ask_pass = False`, o Ansible **nunca** pergunta senha de sudo interativamente — então o `ansible-svc` precisa ter sudo **sem senha** (`NOPASSWD`), senão qualquer task que precise de root trava/falha.

Na VM, como root (ou outro usuário com sudo):

```bash
sudo useradd -m -s /bin/bash ansible-svc

echo "ansible-svc ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible-svc
sudo chmod 440 /etc/sudoers.d/ansible-svc
```

### 2. Chave SSH

A autenticação é sempre por chave — não há suporte a senha de SSH neste fluxo (`ansible_ssh_private_key_file` no inventário). O par de chaves é gerado na máquina que roda o Ansible (o runner), e só a **chave pública** vai para a VM; a privada nunca sai do runner.

Na máquina que roda o Ansible:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/awx_ansible -C "ansible-svc@awx-iac" -N ""
```

Autorizar a chave pública para o usuário `ansible-svc` na VM (esse passo único ainda precisa de outro método de acesso à VM, já que a chave nova ainda não está autorizada):

```bash
ssh-copy-id -i ~/.ssh/awx_ansible.pub ansible-svc@<IP_DA_VM>
```

A chave privada (`~/.ssh/awx_ansible`, sem `.pub`) é o valor que vai em `SSH_KEY=` no `scripts/install.sh` (ou `awx_ssh_key_path` diretamente no Ansible) — se nada for informado, o padrão é `~/.ssh/id_ed25519` (ver [ansible/inventory/hosts.yml:9](ansible/inventory/hosts.yml)).

### 3. Validar o acesso

Antes de rodar o playbook, confirme que a chave e o sudo sem senha estão funcionando — os dois pontos que mais costumam travar uma primeira instalação:

```bash
# Autentica por chave, sem pedir senha
ssh -i ~/.ssh/awx_ansible ansible-svc@<IP_DA_VM> "whoami"

# Confirma sudo sem senha (é exatamente o que o `become` do Ansible vai usar)
ssh -i ~/.ssh/awx_ansible ansible-svc@<IP_DA_VM> "sudo -n true && echo 'sudo OK'"
```

Ou, de forma mais fiel ao que o playbook de fato faz, direto pelo Ansible:

```bash
ansible awx-server -i ansible/inventory/hosts.yml \
  -e awx_host_ip=<IP_DA_VM> -e awx_ssh_key_path=~/.ssh/awx_ansible \
  -m ping
```

Uma resposta `"ping": "pong"` confirma que chave e sudo estão OK e o [scripts/install.sh](scripts/install.sh) pode rodar.

> Nota: o `ansible.cfg` também define `host_key_checking = False`, então a primeira conexão SSH não vai pedir confirmação de host key. Isso é aceitável numa rede interna controlada, mas é uma checagem de segurança que fica deliberadamente desligada — vale ter em mente.

---

## Como executar

Pré-requisito, uma vez, na máquina que vai rodar o Ansible (ex: o runner local):

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

Instalação — bootstrap do RKE2 + deploy do AWX na VM alvo:

```bash
AWX_HOST_IP=10.190.1.250 SSH_KEY=~/.ssh/awx_ansible ./scripts/install.sh
```

Isso roda o playbook [ansible/playbooks/site.yml](ansible/playbooks/site.yml), que executa em sequência:

1. Role `rke2` — instala e inicia o RKE2 na VM (idempotente)
2. Role `awx` — aplica o awx-operator via Kustomize (versão pinada) e a Custom Resource do AWX; tudo roda com `kubectl` localmente na própria VM, usando o kubeconfig gerado pelo RKE2, sem precisar expor a API do cluster para fora da rede privada

A senha de admin é gerada automaticamente pelo awx-operator e **nunca é impressa pelo Ansible**. Ao final da execução, o playbook mostra o comando para buscá-la sob demanda:

```bash
kubectl get secret awx-admin-password -n awx -o jsonpath='{.data.password}' | base64 -d
```

---

## CI/CD

Workflows em `.github/workflows/` (GitHub Actions):

- **`lint.yml`** — roda em todo push/PR, em runner hospedado pelo GitHub (não precisa de acesso à rede da VM). Valida formatação (Prettier), `ansible-lint`, syntax-check do playbook, renderização do Kustomize e shellcheck dos scripts.
- **Deploy automatizado** - deploy automático, instalação e configuração do AWX Tower orquestrado por Kubernets. Trigger de disparo manual, pode informar o IP da máquina alvo (onde será instalado), caso não for informado, será pego o valor definido na variável do repositório **AWX_HOST_IP**

---

## Contexto e decisões

- Épico de origem: ODM-809
- Documento de avaliação técnica e decisão de arquitetura: `docs/AWX_Avaliacao_Instalacao_Legada.md` _(a adicionar)_
- Versão de referência do awx-operator: `2.19.1` (AWX `24.6.1`) — também a mais recente disponível; o projeto AWX está com releases pausados desde jul/2024 por conta de uma refatoração de arquitetura em andamento, então não há versão mais nova a validar por enquanto.
- Storage do Postgres do AWX: `local-path` (nativo do RKE2), em vez do Longhorn usado na instalação legada — dispensa dependência extra num cluster single-node.

---

## Formatação de código

Este repositório usa o [Prettier](https://prettier.io/) para manter a formatação dos arquivos (YAML, Markdown, JSON) consistente entre todos os contribuidores.

### Instalação

O Prettier roda sobre Node.js/npm. Instale o Node.js de acordo com o seu sistema operacional:

**macOS** (via [Homebrew](https://brew.sh/)):

```bash
brew install node
```

**Linux (Debian/Ubuntu)**:

```bash
sudo apt update
sudo apt install nodejs npm
```

**Linux (Fedora/RHEL/CentOS)**:

```bash
sudo dnf install nodejs npm
```

**Windows**:

- Via [instalador oficial](https://nodejs.org/): baixe e execute o `.msi` da versão LTS.
- Ou via [Chocolatey](https://chocolatey.org/) (PowerShell como administrador):

  ```powershell
  choco install nodejs-lts
  ```

- Ou via [winget](https://learn.microsoft.com/windows/package-manager/winget/):

  ```powershell
  winget install OpenJS.NodeJS.LTS
  ```

Com o Node.js/npm instalados, instale as dependências do projeto (o Prettier) a partir da raiz do repositório:

```bash
npm install
```

### Uso

```bash
npx prettier --check .   # verifica se há arquivos fora do padrão, sem alterá-los
npx prettier --write .   # formata todos os arquivos automaticamente
```

A configuração fica em `.prettierrc.json`; arquivos ignorados pela formatação estão listados em `.prettierignore`.

### Pre-commit hook (recomendado)

Depois de clonar o repositório, ative o hook que formata automaticamente os arquivos staged antes de cada commit (evita que problemas de formatação só sejam pegos lá na CI):

```bash
git config core.hooksPath .githooks
```

Isso é um ajuste local por clone (não é versionado pelo git em si) — precisa rodar uma vez em cada máquina/checkout. O `.editorconfig` do repositório complementa isso configurando o editor (indentação, newline final, etc.) durante a edição.
