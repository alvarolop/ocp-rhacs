# 🛡️ OpenShift — Advanced Cluster Security (RHACS)

This repository automates the deployment and day-2 configuration of [Red Hat Advanced Cluster Security for Kubernetes (RHACS)](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_security_for_kubernetes/4.10/html/architecture/index) on OpenShift using a **GitOps approach** with ArgoCD and Kustomize.

> [!NOTE]
> This repo focuses on **container security** (vulnerability scanning, runtime protection, compliance). If you are looking for **secrets and certificate management** (Vault, cert-manager, External Secrets Operator, etc.), check out [ocp-secured-integration](https://github.com/alvarolop/ocp-secured-integration) instead.

---

## Table of Contents

- [Introduction](#introduction)
- [Features](#-features)
- [Repository Structure](#-repository-structure)
- [Prerequisites](#-prerequisites)
- [How to Run](#-how-to-run)
- [Container Image](#-container-image)
- [Useful Documentation](#-useful-documentation)

---

## Introduction

**Red Hat Advanced Cluster Security for Kubernetes (RHACS)** is an enterprise-ready, Kubernetes-native security platform that helps you secure the build, deploy, and runtime phases of your containerized applications.

RHACS uses a **distributed architecture** composed of two sets of services:

- **Central services** — installed on *one* cluster — provide the management plane:
  - **Central** — the API server and web UI (RHACS Portal).
  - **Central DB** — PostgreSQL-based persistence layer.
  - **Scanner V4** — the default vulnerability scanner (Indexer, Matcher, and DB) built on ClairCore.

- **Secured cluster services** — installed on *every* cluster you want to protect:
  - **Sensor** — monitors the cluster API and triggers policy violations.
  - **Admission controller** — blocks workloads that violate security policies at deploy time.
  - **Collector** — analyzes container runtime and network activity on each node using eBPF (CORE_BPF).
  - **Scanner V4** (Indexer + DB) — enables local image scanning for integrated registries and delegated scanning.

Central and Secured cluster services communicate over **gRPC/TLS on port 443**. Scanner V4 components use gRPC on port 8443 and PostgreSQL on port 5432.

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
| ✅ **Compliance Operator** | A separate ArgoCD Application installs the **Compliance Operator** in `openshift-compliance`, ready for you to apply `ScanSettings` and `Profiles`. |

Additional capabilities include a **ConsoleLink** component (adds RHACS to the OpenShift Application Menu under "Security") and a Job to **enable the RHACS dynamic console plugin** (available but commented out for opt-in).

---

## 📂 Repository Structure

```text
ocp-rhacs/
├── application-rhacs.yaml            # ArgoCD App: RHACS operator + Central + day-2 jobs
├── application-compliance.yaml       # ArgoCD App: Compliance Operator
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
└── gitops-compliance/
    ├── kustomization.yaml
    └── operator/                     # Compliance Operator (Namespace, OperatorGroup, Subscription)
```

---

## 📋 Prerequisites

> [!TIP]
> You need a running **OpenShift GitOps** (ArgoCD) instance in your cluster. If you don't have one, you can use [ocp-gitops-playground](https://github.com/alvarolop/ocp-gitops-playground) — clone it and run `./auto-install.sh` to deploy a fully configured ArgoCD.

- OpenShift Container Platform **4.14+**
- OpenShift GitOps operator installed
- `oc` CLI authenticated as `cluster-admin`

---

## 🚀 How to Run

### Option 1: Deploy everything with ArgoCD (recommended)

Deploy the full RHACS stack (operator, Central, secured cluster, day-2 jobs, OIDC auth, and console link) by applying the ArgoCD Application:

```bash
# Replace $CLUSTER_DOMAIN with your cluster's base domain
# e.g., cluster-abc.sandbox123.opentlc.com
export CLUSTER_DOMAIN=$(oc get dns.config/cluster -o jsonpath='{.spec.baseDomain}')

cat application-rhacs.yaml | envsubst | oc apply -f -
```

> [!IMPORTANT]
> The `application-rhacs.yaml` contains `$CLUSTER_DOMAIN` placeholders that configure the Central route URL, OIDC callback, and ConsoleLink. You **must** substitute them before applying.

To also deploy the Compliance Operator:

```bash
oc apply -f application-compliance.yaml
```

### Option 2: Render and apply independently with Kustomize

You can render each component individually without ArgoCD:

#### RHACS core (operator + Central + day-2 jobs)

```bash
kustomize build gitops-rhacs/ | oc apply -f -
```

#### RHACS with OpenShift built-in auth

Temporarily add the component to `gitops-rhacs/kustomization.yaml`:

```yaml
components:
  - components/auth-openshift
  - components/consolelink
```

Then render:

```bash
kustomize build gitops-rhacs/ | oc apply -f -
```

#### Compliance Operator only

```bash
kustomize build gitops-compliance/ | oc apply -f -
```

### Option 3: Deploy individual resources

You can also apply specific sub-directories for granular control:

```bash
# 1) Install only the RHACS operator
kustomize build gitops-rhacs/operator/ | oc apply -f -

# 2) Wait for the operator to be ready
echo -n "Waiting for RHACS operator pods..."
while ! oc get csv -n rhacs-operator -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Succeeded; do
  echo -n "." && sleep 5
done
echo " ✅"

# 3) Create namespace and deploy Central
oc apply -f gitops-rhacs/ns-stackrox.yaml
oc apply -f gitops-rhacs/central-stackrox-central-services.yaml

# 4) Run the cluster registration job
kustomize build gitops-rhacs/job-cluster-registration/ | oc apply -f -

# 5) Deploy the secured cluster
oc apply -f gitops-rhacs/securedcluster-local.yaml
```

---

## 🐳 Container Image

Some of the day-2 Jobs require `curl`, `oc`, and `roxctl` in the same container. Since no Red Hat-supported image ships all three, this repo includes a `Dockerfile` that builds a minimal image based on `ubi9-minimal`:

```bash
# Build (optionally override RHACS_VERSION)
podman build -t quay.io/alopezme/rhacs-roxctl-oc:4.10 \
  --build-arg RHACS_VERSION=4.10.0 .

# Push
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
