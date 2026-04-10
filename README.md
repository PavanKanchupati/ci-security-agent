# 🛡️ CI Security Agent

<div align="center">

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Docker Pulls](https://img.shields.io/badge/docker-ready-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Kubernetes](https://img.shields.io/badge/kubernetes-ready-blue)
![EKS](https://img.shields.io/badge/EKS-compatible-orange)
![Security](https://img.shields.io/badge/security-SBOM%20%7C%20Signing-red)

**Enterprise-grade CI/CD agent with built-in security scanning, container signing, and cloud-native tooling**

[Features](#features) • [Quick Start](#quick-start) • [Architecture](#architecture) • [Tools](#tools-included) • [Security](#security-first) • [Contributing](#contributing)

</div>

---

## 📋 Overview

CI Security Agent is a **production-ready Docker image** designed for Jenkins and GitHub Actions runners in Kubernetes (EKS) environments. It bundles essential security scanning tools, infrastructure-as-code utilities, and container signing capabilities in a single, verified image.

**Why CI Security Agent?**
- 🔒 **Supply Chain Security** - Built-in SBOM generation, vulnerability scanning, and image signing
- 🚀 **Zero Configuration** - Pre-configured with best practices for EKS and cloud environments
- 📦 **All-in-One** - 15+ security and DevOps tools in a single image
- ✅ **Verified Builds** - Cosign-signed images with attestation

---

## ✨ Features

### 🔐 Security First
- **Vulnerability Scanning** - Trivy scans for CVEs in dependencies and binaries
- **SBOM Generation** - Syft creates SPDX-compliant software bills of materials
- **SBOM Analysis** - Grype identifies vulnerabilities in SBOMs
- **Image Signing** - Cosign signs images and attestations with Sigstore

### ☁️ Cloud Native
- **AWS ECR Integration** - Native push/pull from Elastic Container Registry
- **Kubernetes Ready** - Works with EKS, Jenkins Kubernetes Plugin, and GitHub ARC
- **Infrastructure as Code** - Terraform, kubectl, and Helm included

### 🛠️ Developer Tools
- **SAST Scanning** - Semgrep for static application security testing
- **SCA Scanning** - OWASP Dependency Check for Java/JavaScript dependencies
- **Container Runtime** - Docker CLI for container operations

---

## 🚀 Quick Start

### Prerequisites

```bash
# Required
- Docker 20.10+
- AWS CLI 2.x (for ECR operations)
- Git 2.0+

# Optional
- Kubernetes cluster (EKS 1.32+)
- Jenkins 2.440+ or GitHub Actions runner