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

*(apenas a estrutura de diretórios está definida por enquanto — conteúdo de cada parte será adicionado e documentado aqui à medida que for implementado)*

---

## Contexto e decisões

- Épico de origem: ODM-809
- Documento de avaliação técnica e decisão de arquitetura: `docs/AWX_Avaliacao_Instalacao_Legada.md` *(a adicionar)*
- Versão de referência do awx-operator (instalação legada, usada como base): `2.19.1` (AWX `24.6.1`) — validar se ainda é a mais recente antes de aplicar

---

## Próximos passos

- [ ] Preencher playbooks de bootstrap do RKE2
- [ ] Preencher `kustomization.yaml` e Custom Resource do AWX
- [ ] Definir mecanismo de secrets
- [ ] Configurar pipeline CI/CD (runner interno, rede não tem rota pública)
- [ ] Documentar processo de backup e restore