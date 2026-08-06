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
awx-infra/
├── ansible/                    # Bootstrap do SO + cluster RKE2
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
├── kubernetes/
│   └── awx/
│       ├── base/                # Kustomization + Custom Resource do AWX
│       └── overlays/            # Customizações por ambiente
├── execution-environments/      # EEs customizadas (ex: integrações específicas)
├── scripts/                     # Backup, health check, utilitários
├── ci/                          # Definição do pipeline
└── docs/                        # Documentação complementar
```

_(apenas a estrutura de diretórios está definida por enquanto — conteúdo de cada parte será adicionado e documentado aqui à medida que for implementado)_

---

## Contexto e decisões

- Épico de origem: ODM-809
- Documento de avaliação técnica e decisão de arquitetura: `docs/AWX_Avaliacao_Instalacao_Legada.md` _(a adicionar)_
- Versão de referência do awx-operator (instalação legada, usada como base): `2.19.1` (AWX `24.6.1`) — validar se ainda é a mais recente antes de aplicar

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

---

## Próximos passos

- [ ] Preencher playbooks de bootstrap do RKE2
- [ ] Preencher `kustomization.yaml` e Custom Resource do AWX
- [ ] Definir mecanismo de secrets
- [ ] Configurar pipeline CI/CD (runner interno, rede não tem rota pública)
- [ ] Documentar processo de backup e restore
