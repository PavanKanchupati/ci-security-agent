# =============================================================================
# CI Agent Image — Jenkins Inbound Agent / GitHub Actions Runner
# Compatible with: EKS (linux/amd64), Jenkins Kubernetes Plugin, GitHub ARC
# Versions verified: April 10, 2026
# =============================================================================

FROM --platform=linux/amd64 jenkins/inbound-agent:alpine-jdk21

# -----------------------------------------------------------------------------
# Tool versions — bump here only
# Verified April 10, 2026:
#   Trivy       0.69.3  — latest SAFE version (0.69.4/0.69.5/0.69.6 compromised)
#   Syft        1.42.3  — latest stable (github.com/anchore/syft)
#   Grype       0.110.0 — latest stable (github.com/anchore/grype)
#   Cosign      2.4.3   — last stable v2 (v3.x has breaking --bundle changes)
#   Terraform   1.14.8  — latest stable GA (1.15.x still in RC/alpha)
#   kubectl     1.33.0  — latest stable (k8s supports 1.35, 1.34, 1.33)
#   Helm        3.20.2  — latest stable v3 (v4 has breaking changes)
#   DepCheck    12.2.0  — latest stable (dependency-check.github.io)
#   Semgrep     1.157.0 — latest stable (pypi.org/project/semgrep)
#   AWS CLI     2.22.35 — latest stable
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Tool versions — bump here only
# Verified working versions as of April 10, 2026:
# -----------------------------------------------------------------------------
ARG TRIVY_VERSION=0.69.3           # Last stable before supply chain attack (v0.69.4+ compromised)
ARG SYFT_VERSION=1.42.3            # Latest stable
ARG GRYPE_VERSION=0.110.0          # Latest stable  
ARG COSIGN_VERSION=2.6.3           # Latest v2 with security patches (v2.6.3 exists)
ARG TERRAFORM_VERSION=1.14.8       # Latest GA (1.15.x still RC)
ARG KUBECTL_VERSION=1.33.0         # Stable version within EKS support window
ARG HELM_VERSION=3.20.2            # Latest stable v3
ARG DEPENDENCY_CHECK_VERSION=12.2.0 # Latest stable
ARG SEMGREP_VERSION=1.157.0        # Latest stable
#ARG AWS_CLI_VERSION=2.22.35        # Latest stable

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
# IMPORTANT: v0.69.3 pinned intentionally.
#            v0.69.4, v0.69.5, v0.69.6 were compromised in March 2026
#            supply chain attack — do NOT upgrade to those versions.
# Checksum file: trivy_X.Y.Z_checksums.txt (NOT .sha256sum — different format)
# -----------------------------------------------------------------------------
RUN TRIVY_TAR="trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
    && TRIVY_CHECKSUMS="trivy_${TRIVY_VERSION}_checksums.txt" \
    && wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_TAR}" \
    && wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${TRIVY_CHECKSUMS}" \
    && grep "${TRIVY_TAR}" "${TRIVY_CHECKSUMS}" | sha256sum -c - \
    && tar -xzf "${TRIVY_TAR}" trivy \
    && mv trivy /usr/local/bin/ \
    && rm -f "${TRIVY_TAR}" "${TRIVY_CHECKSUMS}" \
    && trivy --version

# -----------------------------------------------------------------------------
# Syft — SBOM generator
# Checksum file: syft_X.Y.Z_checksums.txt
# -----------------------------------------------------------------------------
RUN SYFT_TAR="syft_${SYFT_VERSION}_linux_amd64.tar.gz" \
    && SYFT_CHECKSUMS="syft_${SYFT_VERSION}_checksums.txt" \
    && wget -q "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/${SYFT_TAR}" \
    && wget -q "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/${SYFT_CHECKSUMS}" \
    && grep "${SYFT_TAR}" "${SYFT_CHECKSUMS}" | sha256sum -c - \
    && tar -xzf "${SYFT_TAR}" syft \
    && mv syft /usr/local/bin/ \
    && rm -f "${SYFT_TAR}" "${SYFT_CHECKSUMS}" \
    && syft version

# -----------------------------------------------------------------------------
# Grype — vulnerability scanner for SBOMs
# Checksum file: grype_X.Y.Z_checksums.txt
# -----------------------------------------------------------------------------
RUN GRYPE_TAR="grype_${GRYPE_VERSION}_linux_amd64.tar.gz" \
    && GRYPE_CHECKSUMS="grype_${GRYPE_VERSION}_checksums.txt" \
    && wget -q "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/${GRYPE_TAR}" \
    && wget -q "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/${GRYPE_CHECKSUMS}" \
    && grep "${GRYPE_TAR}" "${GRYPE_CHECKSUMS}" | sha256sum -c - \
    && tar -xzf "${GRYPE_TAR}" grype \
    && mv grype /usr/local/bin/ \
    && rm -f "${GRYPE_TAR}" "${GRYPE_CHECKSUMS}" \
    && grype version

# -----------------------------------------------------------------------------
# Cosign — copied from official image (pinned v2.4.3, last stable v2)
# Using COPY --from avoids download + checksum format issues entirely
# -----------------------------------------------------------------------------
COPY --from=gcr.io/projectsigstore/cosign:v2.4.3 /ko-app/cosign /usr/local/bin/cosign
RUN cosign version


# -----------------------------------------------------------------------------
# AWS CLI v2 — official versioned installer with signature verification
# -----------------------------------------------------------------------------
#RUN curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" \
#        -o /tmp/awscliv2.zip \
#   && curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip.sig" \
 #        -o /tmp/awscliv2.zip.sig \
 #   && unzip -q /tmp/awscliv2.zip -d /tmp \
  #  && /tmp/aws/install \
   # && rm -rf /tmp/awscliv2.zip /tmp/awscliv2.zip.sig /tmp/aws \
    #&& aws --version

# -----------------------------------------------------------------------------
# Terraform — latest stable GA
# NOTE: 1.15.x is still in RC/alpha as of Apr 2026. Use 1.14.8 (latest GA).
# Checksum file: terraform_X.Y.Z_SHA256SUMS
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
# kubectl — within supported k8s version window (1.35/1.34/1.33 active Apr 2026)
# Using 1.33.0 — safe ±1 skew with EKS 1.32/1.33/1.34 clusters
# -----------------------------------------------------------------------------
RUN curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && curl -sLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" \
    && echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/ \
    && rm -f kubectl.sha256 \
    && kubectl version --client

# -----------------------------------------------------------------------------
# Helm v3 — latest stable v3
# NOTE: Helm v4 released Nov 2025 (KubeCon). Latest v4 is 4.1.4 (Apr 2026).
#       v4 has breaking changes: server-side apply, new plugin system.
#       Staying on v3 until your charts and CI are validated against v4.
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
# OWASP Dependency Check — Java SCA scanner
# NOTE: NVD data dir should be mounted as PVC in EKS to avoid
#       20+ minute NVD download on every run.
#       Pass --nvdApiKey at runtime via env — NOT baked into image.
# Repo moved from jeremylong to dependency-check org on GitHub.
# -----------------------------------------------------------------------------
RUN DC_ZIP="dependency-check-${DEPENDENCY_CHECK_VERSION}-release.zip" \
    && wget -q "https://github.com/dependency-check/DependencyCheck/releases/download/v${DEPENDENCY_CHECK_VERSION}/${DC_ZIP}" \
    && unzip -q "${DC_ZIP}" \
    && mv dependency-check /opt/dependency-check \
    && ln -s /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check \
    && rm -f "${DC_ZIP}" \
    && mkdir -p /opt/dependency-check/data \
    && chown -R jenkins:jenkins /opt/dependency-check \
    && dependency-check --version

# -----------------------------------------------------------------------------
# Semgrep — SAST scanner (isolated venv, no system-pip pollution)
# NOTE: Semgrep releases weekly. Pinning deliberately to avoid surprise.
#       1.157.0 is latest as of March 31, 2026.
# -----------------------------------------------------------------------------
RUN python3 -m venv /opt/semgrep-env \
    && /opt/semgrep-env/bin/pip install --no-cache-dir "semgrep==${SEMGREP_VERSION}" \
    && ln -s /opt/semgrep-env/bin/semgrep /usr/local/bin/semgrep \
    && semgrep --version

# -----------------------------------------------------------------------------
# Runtime environment
# -----------------------------------------------------------------------------
ENV SEMGREP_CACHE_PATH=/tmp/semgrep-cache \
    TRIVY_CACHE_DIR=/tmp/trivy-cache \
    GRYPE_DB_CACHE_DIR=/tmp/grype-db \
    JAVA_OPTS="-Xmx512m -XX:+UseContainerSupport" \
    PATH="/usr/local/bin:${PATH}"

# Secrets injected at RUNTIME only — never baked into image:
#   NVD_API_KEY     → dependency-check NVD rate limits
#   COSIGN_PASSWORD → cosign key decryption
#
# On EC2 Jenkins:
#   aws secretsmanager get-secret-value --secret-id platform/cosign-password
#
# On EKS agents (Phase 2):
#   Secrets Store CSI Driver mounts from AWS Secrets Manager
#   Path: /mnt/cosign-secrets/cosign.key and /mnt/cosign-secrets/cosign.password

# -----------------------------------------------------------------------------
# Filesystem hygiene — pre-create cache dirs owned by jenkins user
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
# OCI Labels — placed LAST to preserve layer cache
# Pass at build time:
#   --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
#   --build-arg VCS_REF=$(git rev-parse --short HEAD)
# -----------------------------------------------------------------------------
ARG BUILD_DATE
ARG VCS_REF

LABEL maintainer="platform-team" \
      org.opencontainers.image.title="CI Security Agent" \
      org.opencontainers.image.description="CI/CD agent with security scanning, IaC, and cloud tools" \
      org.opencontainers.image.base.name="jenkins/inbound-agent:alpine-jdk21" \
      org.opencontainers.image.source="https://github.com/PavanKanchupati/ci-security-agent" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="2.0.0"

# -----------------------------------------------------------------------------
# Drop privileges — always last instruction before ENTRYPOINT
# -----------------------------------------------------------------------------
USER jenkins
WORKDIR /home/jenkins/agent

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]