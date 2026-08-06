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
- **Deploy automatizado** _(planejado, ainda não implementado)_ — vai rodar no runner self-hosted `siquela-macbook-runner` (o único com rota até a rede privada da VM), disparado automaticamente no push para `main` e também sob demanda (`workflow_dispatch`), com um gate de aprovação manual (GitHub Environment `production`) antes de tocar na infraestrutura real.

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

---

## Próximos passos

- [x] Preencher playbooks de bootstrap do RKE2
- [x] Preencher `kustomization.yaml` e Custom Resource do AWX
- [x] Definir mecanismo de secrets (senha gerada automaticamente pelo awx-operator; nunca exposta em log/CI)
- [x] Lint e validação automatizados (`lint.yml`)
- [ ] Implementar o workflow de deploy automatizado no runner self-hosted (`siquela-macbook-runner`)
- [ ] Documentar processo de backup e restore
