# 🛡️ OpenShift — Advanced Cluster Security (RHACS)

This repository automates the deployment and day-2 configuration of [Red Hat Advanced Cluster Security for Kubernetes (RHACS)](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.10/html/architecture/index) on OpenShift using a **GitOps approach** with ArgoCD and Kustomize. The goal is to **set up a fully functional RHACS environment in a single click**, ideal for demos, workshops, and testing scenarios.

> [!NOTE]
> This repo focuses on **container security** (vulnerability scanning, runtime protection, compliance). If you are looking for **secrets and certificate management** (Vault, cert-manager, External Secrets Operator, etc.), check out [ocp-secured-integration](https://github.com/alvarolop/ocp-secured-integration) instead.

---

## Introduction

**Red Hat Advanced Cluster Security for Kubernetes (RHACS)** is an enterprise-ready, Kubernetes-native security platform that helps you secure the build, deploy, and runtime phases of your containerized applications.

RHACS uses a **distributed architecture** composed of two sets of services:

<p align="center">
  <img src="https://access.redhat.com/webassets/avalon/d/Red_Hat_Advanced_Cluster_Security_for_Kubernetes-3.69-Architecture-en-US/images/84f94bd69b33eac318dc15dc8fbf51fb/acs-architecture-ocp.png" alt="RHACS Architecture on OpenShift" width="700">
</p>

- **Central services** — installed on *one* cluster — provide the management plane:
  - **Central** — the API server and web UI (RHACS Portal).
  - **Central DB** — PostgreSQL-based persistence layer.
  - **Scanner V4** — the default vulnerability scanner (Indexer, Matcher, and DB) built on ClairCore.

- **Secured cluster services** — installed on *every* cluster you want to protect:
  - **Sensor** — monitors the cluster API and triggers policy violations.
  - **Admission controller** — blocks workloads that violate security policies at deploy time.
  - **Collector** — analyzes container runtime and network activity on each node using eBPF (CORE_BPF).
  - **Scanner V4** (Indexer + DB) — enables local image scanning for integrated registries and delegated scanning.

For a detailed architecture reference, see the [official RHACS 4.10 Architecture documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.10/html/architecture/index).

---

## ✨ Features

This repository provides the following key automations, all driven by ArgoCD Applications and Kustomize:

| Feature | Description |
|---------|-------------|
| 🚀 **Full RHACS deployment** | Installs the RHACS operator, creates the `stackrox` namespace, and deploys a production-ready **Central** instance with re-encrypt route, OpenShift monitoring, and persistent storage — all in a single ArgoCD sync. |
| 🔑 **Automated Cluster Registration** | An ArgoCD Sync Hook Job uses `roxctl` to generate a **Cluster Registration Secret (CRS)** and applies it to the cluster, eliminating the manual `init-bundle` workflow. |
| 📦 **Offline vulnerability definitions** | A daily CronJob downloads the scanner vulnerability database from `stackrox.io` and uploads it to Central via `roxctl scanner upload-db`, enabling **disconnected / air-gapped** environments. |
| 🔐 **Declarative authentication** | Kustomize components configure Central's auth provider declaratively — choose between **OpenShift built-in auth** or **OpenShift OIDC** (with `OAuthClient`) without manual UI steps. |
| ✅ **Compliance Operator** | A separate ArgoCD Application installs the **Compliance Operator** in `openshift-compliance` and binds the **DISA STIG** profiles (`ocp4-stig` + `ocp4-stig-node`) to the built-in `default` ScanSetting. Results are automatically visible in the RHACS Compliance dashboard. |
| 🔍 **File Integrity Operator** | A separate ArgoCD Application installs the **File Integrity Operator** in `openshift-file-integrity`. It deploys AIDE-based DaemonSets that continuously monitor RHCOS nodes for unauthorized file changes. |

Additional capabilities include a **ConsoleLink** component (adds RHACS to the OpenShift Application Menu under "Security") and a Job to **enable the RHACS dynamic console plugin** (available but commented out for opt-in).

---

## 📂 Repository Structure

```text
ocp-rhacs/
├── application-rhacs.yaml            # ArgoCD App: RHACS operator + Central + day-2 jobs
├── application-compliance.yaml       # ArgoCD App: Compliance Operator
├── application-file-integrity.yaml   # ArgoCD App: File Integrity Operator
├── Dockerfile                        # Custom image: ubi9 + roxctl + oc
├── .github/workflows/
│   └── build-image.yaml              # Weekly build of quay.io/alopezme/rhacs-roxctl-oc
│
├── gitops-rhacs/
│   ├── kustomization.yaml            # Root kustomization
│   ├── operator/                     # RHACS operator (Namespace, OperatorGroup, Subscription)
│   ├── ns-stackrox.yaml              # stackrox namespace
│   ├── central-stackrox-central-services.yaml  # Central CR
│   ├── securedcluster-local.yaml     # SecuredCluster CR (local cluster)
│   ├── job-cluster-registration/     # Job: CRS generation via roxctl
│   ├── job-fetch-vuln-definitions/   # CronJob: offline vuln upload
│   ├── job-enable-plugin/            # Job: dynamic console plugin (opt-in)
│   └── components/
│       ├── auth-oidc/                # Component: OpenShift OIDC auth provider
│       ├── auth-openshift/           # Component: OpenShift built-in auth provider
│       └── consolelink/              # Component: RHACS link in OCP console menu
│
├── gitops-compliance/
│   ├── kustomization.yaml
│   ├── scansettingbinding-stig.yaml  # DISA STIG scan (ocp4-stig + ocp4-stig-node)
│   └── operator/                     # Compliance Operator (Namespace, OperatorGroup, Subscription)
│
└── gitops-file-integrity/
    ├── kustomization.yaml
    ├── fileintegrity-worker.yaml     # FileIntegrity CR: AIDE scans on worker nodes
    ├── fileintegrity-master.yaml     # FileIntegrity CR: AIDE scans on master nodes
    └── operator/                     # File Integrity Operator (Namespace, OperatorGroup, Subscription)
```

---

## 📋 Prerequisites

> [!TIP]
> You need a running **OpenShift GitOps** (ArgoCD) instance in your cluster. If you don't have one, you can use [ocp-gitops-playground](https://github.com/alvarolop/ocp-gitops-playground) — clone it and run `./auto-install.sh` to deploy a fully configured ArgoCD.

- OpenShift Container Platform **4.18+**
- OpenShift GitOps operator installed
- `oc` CLI authenticated as `cluster-admin`

---

## 🚀 How to Run

Deploy the full RHACS stack (operator, Central, secured cluster, day-2 jobs, OpenShift auth, and console link) by applying the ArgoCD Application:

```bash
export CLUSTER_DOMAIN=$(oc get dns.config/cluster -o jsonpath='{.spec.baseDomain}')

cat application-rhacs.yaml | envsubst | oc apply -f -
```

> [!IMPORTANT]
> The `application-rhacs.yaml` contains a `$CLUSTER_DOMAIN` placeholder used by the ConsoleLink. You **must** substitute it before applying. To switch to OIDC-based auth instead, change the component from `auth-openshift` to `auth-oidc` in the application and add the required OIDC patches (see `components/auth-oidc/`).

To also deploy the Compliance Operator and the File Integrity Operator:

```bash
oc apply -f application-compliance.yaml
oc apply -f application-file-integrity.yaml
```

Wait for ArgoCD to sync, and within a few minutes you will have a fully operational RHACS environment — Central, SecuredCluster, authentication, and vulnerability definitions — ready to explore.

---

## 🐳 Container Image

Some of the day-2 Jobs require `curl`, `oc`, and `roxctl` in the same container. Since no Red Hat-supported image ships all three, this repo includes a `Dockerfile` that builds a minimal image based on `ubi9-minimal`:

```bash
podman build -t quay.io/alopezme/rhacs-roxctl-oc:4.10 \
  --build-arg RHACS_VERSION=4.10.0 .

podman push quay.io/alopezme/rhacs-roxctl-oc:4.10
```

> [!NOTE]
> A GitHub Actions workflow (`.github/workflows/build-image.yaml`) rebuilds and pushes this image weekly to `quay.io/alopezme/rhacs-roxctl-oc` with tags `4.10` and `latest`.

---

## 📚 Useful Documentation

- [RHACS 4.10 Architecture](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.10/html/architecture/index)
- [RHACS 4.10 Product Documentation](https://docs.openshift.com/acs/4.10/welcome/index.html)
- [Red Hat Scholars — ACS Workshop](https://redhat-scholars.github.io/acs-workshop/acs-workshop/index.html)
- [StackRox Contributions — community resources](https://github.com/stackrox/contributions)
- [RHACS GitOps Helm Chart reference](https://github.com/nmasse-itix/rhacs-gitops/tree/main)
- [Ansible ACS Policy Management example](https://github.com/neilcar/ansible-acs-policy-mgmt)
