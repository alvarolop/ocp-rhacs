FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

ARG RHACS_VERSION=4.10.0

LABEL org.opencontainers.image.authors="alopezme@redhat.com"

RUN microdnf install -y --nodocs curl tar gzip \
    && microdnf clean all \
    && rm -rf /var/cache/yum

RUN curl -fsSL -o /usr/local/bin/roxctl \
        "https://mirror.openshift.com/pub/rhacs/assets/${RHACS_VERSION}/bin/Linux/roxctl" \
    && chmod +x /usr/local/bin/roxctl

RUN curl -fsSL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux-amd64-rhel9.tar.gz \
    | tar xzf - -C /usr/local/bin oc kubectl \
    && chmod +x /usr/local/bin/oc /usr/local/bin/kubectl
