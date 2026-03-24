FROM registry.access.redhat.com/advanced-cluster-security/rhacs-roxctl-rhel8:4.10

LABEL org.opencontainers.image.authors="alopezme@redhat.com"

RUN dnf install -y --nodocs curl tar gzip \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN curl -fsSL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux-amd64-rhel8.tar.gz \
    | tar xzf - -C /usr/local/bin oc kubectl \
    && chmod +x /usr/local/bin/oc /usr/local/bin/kubectl
