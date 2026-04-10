pipeline {
  agent any

  environment {
    AWS_REGION   = "ap-south-1"
    ECR_REGISTRY = "959959864512.dkr.ecr.ap-south-1.amazonaws.com"
    ECR_REPO     = "platform/ci-agent"
    IMAGE_TAG    = "1.0.0"
    IMAGE_URI    = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"
  }

  stages {

    stage('Build') {
      steps {
        sh """
          docker build \
            --build-arg BUILD_DATE=\$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
            --build-arg VCS_REF=\$(git rev-parse --short HEAD) \
            -t ${IMAGE_URI} .
        """
      }
    }

    stage('Scan — Trivy') {
      steps {
        sh """
          trivy image \
            --severity CRITICAL \
            --exit-code 0 \
            --no-progress \
            ${IMAGE_URI}
        """
      }
    }

    stage('SBOM — Syft') {
      steps {
        sh """
          syft ${IMAGE_URI} \
            -o spdx-json \
            --file sbom.spdx.json --fail-on none || true
        """
        archiveArtifacts artifacts: 'sbom.spdx.json'
      }
    }

    stage('Scan SBOM — Grype') {
      steps {
        sh """
          grype sbom:./sbom.spdx.json \
            --fail-on critical
        """
      }
    }

    stage('Push to ECR') {
      steps {
        sh """
          aws ecr get-login-password --region ${AWS_REGION} \
            | docker login \
                --username AWS \
                --password-stdin ${ECR_REGISTRY}

          docker push ${IMAGE_URI}

          docker inspect \
            --format='{{index .RepoDigests 0}}' \
            ${IMAGE_URI} > image_digest.txt

          echo "Pushed: \$(cat image_digest.txt)"
        """
        archiveArtifacts artifacts: 'image_digest.txt'
      }
    }

    stage('Sign & Attest — Cosign') {
      steps {
        sh """
          COSIGN_PASSWORD=\$(aws secretsmanager get-secret-value \
            --secret-id platform/cosign-password \
            --region ${AWS_REGION} \
            --query SecretString \
            --output text)

          aws secretsmanager get-secret-value \
            --secret-id platform/cosign-private-key \
            --region ${AWS_REGION} \
            --query SecretString \
            --output text > /tmp/cosign.key

          chmod 600 /tmp/cosign.key

          IMAGE_DIGEST=\$(cat image_digest.txt)

          COSIGN_PASSWORD=\$COSIGN_PASSWORD \
          cosign sign \
            --key /tmp/cosign.key \
            --yes \
            \$IMAGE_DIGEST

          echo "✅ Image signed"

          COSIGN_PASSWORD=\$COSIGN_PASSWORD \
          cosign attest \
            --key /tmp/cosign.key \
            --type spdxjson \
            --predicate sbom.spdx.json \
            --yes \
            \$IMAGE_DIGEST

          echo "✅ SBOM attested"

          rm -f /tmp/cosign.key
        """
      }
    }

    stage('Verify — Cosign') {
      steps {
        sh """
          IMAGE_DIGEST=\$(cat image_digest.txt)

          cosign verify \
            --key ${WORKSPACE}/cosign.pub \
            \$IMAGE_DIGEST

          cosign verify-attestation \
            --key ${WORKSPACE}/cosign.pub \
            --type spdxjson \
            \$IMAGE_DIGEST | jq '.payload | @base64d | fromjson | .predicateType'

          echo "✅ Verified"
        """
      }
    }
  }

  post {
    always {
      sh 'rm -f /tmp/cosign.key'
      sh "docker rmi ${IMAGE_URI} || true"
    }
    success {
      echo "✅ Image ready: ${IMAGE_URI}"
    }
    failure {
      sh 'rm -f /tmp/cosign.key || true'
    }
  }
}
