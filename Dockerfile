# =============================================================================
# CI Agent Image — Jenkins Inbound Agent / GitHub Actions Runner
# Compatible with: EKS (linux/amd64), Jenkins Kubernetes Plugin, GitHub ARC
# =============================================================================

FROM --platform=linux/amd64 jenkins/inbound-agent:alpine-jdk21

#LABEL maintainer="platform-team" \
#      description="CI/CD agent with security scanning, IaC, and cloud tools" \
#      org.opencontainers.image.base.name="jenkins/inbound-agent:alpine-jdk21"

# -----------------------------------------------------------------------------
# Tool versions — bump here only
# -----------------------------------------------------------------------------
ARG TRIVY_VERSION=0.61.0
ARG SYFT_VERSION=1.19.0
ARG GRYPE_VERSION=0.88.0
ARG COSIGN_VERSION=2.4.3
ARG TERRAFORM_VERSION=1.11.3
ARG KUBECTL_VERSION=1.32.3
ARG HELM_VERSION=3.17.2
ARG DEPENDENCY_CHECK_VERSION=12.1.0
ARG SEMGREP_VERSION=1.90.0
ARG AWS_CLI_VERSION=2.22.35

USER root

# -----------------------------------------------------------------------------
# Base OS packages (single layer)
# -----------------------------------------------------------------------------
RUN apk update && apk add --no-cache \
        wget \
        curl \
        unzip \
        git \
        python3 \
        py3-pip \
        py3-virtualenv \
        docker-cli \
        ca-certificates \
        bash \
        jq \
        tar \
        gzip \
        openssl \
        coreutils \
    && rm -rf /var/cache/apk/*

# -----------------------------------------------------------------------------
# Trivy — vulnerability scanner
# Checksum: https://github.com/aquasecurity/trivy/releases
# -----------------------------------------------------------------------------
RUN TRIVY_TAR="trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
    && wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_TAR}" \
    && wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_TAR}.sha256sum" \
    && sha256sum -c "${TRIVY_TAR}.sha256sum" \
    && tar -xzf "${TRIVY_TAR}" trivy \
    && mv trivy /usr/local/bin/ \
    && rm -f "${TRIVY_TAR}" "${TRIVY_TAR}.sha256sum" \
    && trivy --version

# -----------------------------------------------------------------------------
# Syft — SBOM generator (pinned release binary)
# -----------------------------------------------------------------------------
RUN SYFT_TAR="syft_${SYFT_VERSION}_linux_amd64.tar.gz" \
    && wget -q "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/${SYFT_TAR}" \
    && wget -q "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/${SYFT_TAR}.sha256" \
    && sha256sum -c "${SYFT_TAR}.sha256" \
    && tar -xzf "${SYFT_TAR}" syft \
    && mv syft /usr/local/bin/ \
    && rm -f "${SYFT_TAR}" "${SYFT_TAR}.sha256" \
    && syft version

# -----------------------------------------------------------------------------
# Grype — vulnerability scanner for SBOMs (pinned release binary)
# -----------------------------------------------------------------------------
RUN GRYPE_TAR="grype_${GRYPE_VERSION}_linux_amd64.tar.gz" \
    && wget -q "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/${GRYPE_TAR}" \
    && wget -q "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/${GRYPE_TAR}.sha256" \
    && sha256sum -c "${GRYPE_TAR}.sha256" \
    && tar -xzf "${GRYPE_TAR}" grype \
    && mv grype /usr/local/bin/ \
    && rm -f "${GRYPE_TAR}" "${GRYPE_TAR}.sha256" \
    && grype version

# -----------------------------------------------------------------------------
# Cosign — container signing & verification
# -----------------------------------------------------------------------------
RUN wget -q "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64" \
         -O /usr/local/bin/cosign \
    && wget -q "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-amd64.sha256" \
    && echo "$(cat cosign-linux-amd64.sha256)  /usr/local/bin/cosign" | sha256sum -c - \
    && chmod +x /usr/local/bin/cosign \
    && rm -f cosign-linux-amd64.sha256 \
    && cosign version

# -----------------------------------------------------------------------------
# AWS CLI v2 — official installer
# -----------------------------------------------------------------------------
RUN curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" \
         -o awscliv2.zip \
    && curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip.sig" \
         -o awscliv2.zip.sig \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip awscliv2.zip.sig aws \
    && aws --version

# -----------------------------------------------------------------------------
# Terraform
# -----------------------------------------------------------------------------
RUN TF_ZIP="terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
    && wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${TF_ZIP}" \
    && wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    && grep "${TF_ZIP}" "terraform_${TERRAFORM_VERSION}_SHA256SUMS" | sha256sum -c - \
    && unzip -q "${TF_ZIP}" \
    && mv terraform /usr/local/bin/ \
    && rm -f "${TF_ZIP}" "terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
    && terraform version

# -----------------------------------------------------------------------------
# kubectl — pinned to minor version matching EKS target (skew ±1 is safe)
# -----------------------------------------------------------------------------
RUN curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" \
    && echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/ \
    && rm -f kubectl.sha256 \
    && kubectl version --client

# -----------------------------------------------------------------------------
# Helm
# -----------------------------------------------------------------------------
RUN HELM_TAR="helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    && wget -q "https://get.helm.sh/${HELM_TAR}" \
    && wget -q "https://get.helm.sh/${HELM_TAR}.sha256sum" \
    && sha256sum -c "${HELM_TAR}.sha256sum" \
    && tar -xzf "${HELM_TAR}" linux-amd64/helm \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && rm -rf linux-amd64 "${HELM_TAR}" "${HELM_TAR}.sha256sum" \
    && helm version

# -----------------------------------------------------------------------------
# OWASP Dependency Check — Java-based SCA scanner
# Data dir mounted as PVC in EKS to avoid NVD download on every run
# -----------------------------------------------------------------------------
RUN DC_ZIP="dependency-check-${DEPENDENCY_CHECK_VERSION}-release.zip" \
    && wget -q "https://github.com/jeremylong/DependencyCheck/releases/download/v${DEPENDENCY_CHECK_VERSION}/${DC_ZIP}" \
    && unzip -q "${DC_ZIP}" \
    && mv dependency-check /opt/dependency-check \
    && ln -s /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check \
    && rm -f "${DC_ZIP}" \
    && mkdir -p /opt/dependency-check/data \
    && chown -R jenkins:jenkins /opt/dependency-check \
    && dependency-check --version

# -----------------------------------------------------------------------------
# Semgrep — SAST scanner (isolated venv, no system-pip pollution)
# -----------------------------------------------------------------------------
RUN python3 -m venv /opt/semgrep-env \
    && /opt/semgrep-env/bin/pip install --no-cache-dir "semgrep==${SEMGREP_VERSION}" \
    && ln -s /opt/semgrep-env/bin/semgrep /usr/local/bin/semgrep \
    && semgrep --version

# -----------------------------------------------------------------------------
# Kaniko — rootless image builder (replaces Docker-in-Docker in EKS)
# Drop this block if you use DinD sidecar instead
# -----------------------------------------------------------------------------
COPY --from=gcr.io/kaniko-project/executor:latest /kaniko/executor /usr/local/bin/kaniko

# -----------------------------------------------------------------------------
# Runtime environment
# -----------------------------------------------------------------------------
ENV SEMGREP_CACHE_PATH=/tmp/semgrep-cache \
    TRIVY_CACHE_DIR=/tmp/trivy-cache \
    GRYPE_DB_CACHE_DIR=/tmp/grype-db \
    # Keep heap reasonable for EKS pod resource limits
    JAVA_OPTS="-Xmx512m -XX:+UseContainerSupport" \
    # PATH additions (tools already in /usr/local/bin, included for clarity)
    PATH="/usr/local/bin:${PATH}"

# NVD_API_KEY must be injected at runtime via EKS Secret / Pod env — NOT here
# Example in your Jenkins pod template or GitHub ARC RunnerSet:
#   env:
#     - name: NVD_API_KEY
#       valueFrom:
#         secretKeyRef:
#           name: nvd-api-key
#           key: value

# -----------------------------------------------------------------------------
# Filesystem hygiene
# -----------------------------------------------------------------------------
RUN mkdir -p \
        /tmp/semgrep-cache \
        /tmp/trivy-cache \
        /tmp/grype-db \
    && chown -R jenkins:jenkins \
        /tmp/semgrep-cache \
        /tmp/trivy-cache \
        /tmp/grype-db

# -----------------------------------------------------------------------------
# Drop privileges
# -----------------------------------------------------------------------------
ARG BUILD_DATE
ARG VCS_REF

LABEL maintainer="platform-team" \
      org.opencontainers.image.title="CI Agent" \
      org.opencontainers.image.description="CI/CD agent with security scanning, IaC, and cloud tools" \
      org.opencontainers.image.base.name="jenkins/inbound-agent:alpine-jdk21" \
      org.opencontainers.image.source="https://github.com/kanchupati-org/ci-agent" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="2.0.0"

USER jenkins
WORKDIR /home/jenkins/agent

# Entrypoint for Jenkins Kubernetes plugin (inbound agent mode)
# For GitHub ARC, override with: ["sleep", "infinity"] or the runner binary
ENTRYPOINT ["/usr/local/bin/jenkins-agent"]