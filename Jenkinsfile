pipeline {
    agent any

    environment {
        IMAGE_NAME    = "mon-api"
        IMAGE_TAG     = "${BUILD_NUMBER}"
        HARBOR_HOST   = "localhost:8081"
        HARBOR_REPO   = "projet"
        FULL_IMAGE    = "${HARBOR_HOST}/${HARBOR_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"
    }

    stages {

        stage('SAST — Bandit') {
            steps {
                sh '''
                    echo "=== Bandit ==="
                    docker run --rm -v $WORKSPACE:/app -w /app python:3.13-slim sh -c "
                        pip install bandit &&
                        bandit -r src/ -f txt -o bandit-report.txt || true
                    "
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'bandit-report.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Secrets — Gitleaks') {
            steps {
                sh '''
                    echo "=== Gitleaks ==="
                    docker run --rm -v $WORKSPACE:/path \
                        zricethezav/gitleaks:latest \
                        detect --source /path --no-git \
                        --report-format json \
                        --report-path /path/gitleaks-report.json || true
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                }
            }
        }

        stage('Tests (Docker)') {
            steps {
                sh '''
                    echo "=== Tests Docker ==="

                    docker run --rm \
                        -v $WORKSPACE:/app \
                        -v $HOME/.cache/pip:/root/.cache/pip \
                        -w /app \
                        python:3.13-slim \
                        sh -c "
                            set -e
                            ls -la
                            pip install -r requirements.txt -r requirements-dev.txt
                            python -m pytest tests/ -v \
                                --junitxml=test-results.xml \
                                --cov=src --cov-report=xml
                        "
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                    archiveArtifacts artifacts: 'test-results.xml', allowEmptyArchive: true
                }
            }
        }

        stage('Dependency Scan — Safety') {
            steps {
                sh '''
                    echo "=== Safety ==="
                    docker run --rm -v $WORKSPACE:/app -w /app python:3.13-slim sh -c "
                        pip install safety &&
                        safety check -r requirements.txt || true
                    "
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "=== Build Docker ==="
                    docker build \
                        -f docker/Dockerfile \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${IMAGE_NAME}:latest .
                '''
            }
        }

        stage('Scan Image — Trivy') {
            steps {
                sh '''
                    echo "=== Trivy scan ==="
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        aquasec/trivy:latest image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        ${IMAGE_NAME}:${IMAGE_TAG}
                '''
            }
        }

        stage('SBOM — Syft') {
            steps {
                sh '''
                    echo "=== SBOM ==="
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        anchore/syft ${IMAGE_NAME}:${IMAGE_TAG} -o table > sbom.txt
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'sbom.txt', allowEmptyArchive: true
                }
            }
        }

        stage('Push Harbor') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-credentials',
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASS'
                )]) {
                    sh '''
                        echo "=== Push Harbor ==="
                        echo "$HARBOR_PASS" | docker login $HARBOR_HOST \
                            -u $HARBOR_USER --password-stdin

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE}
                        docker push ${FULL_IMAGE}
                    '''
                }
            }
        }

        stage('Sign Image (Cosign)') {
            steps {
                sh '''
                    echo "=== Sign Image ==="
                    chmod +x scripts/sign.sh
                    ./scripts/sign.sh ${FULL_IMAGE}
                '''
            }
        }

        stage('Verify Image') {
            steps {
                sh '''
                    echo "=== Verify Image ==="
                    chmod +x scripts/verify.sh
                    ./scripts/verify.sh ${FULL_IMAGE}
                '''
            }
        }

        stage('Deploy — Ansible') {
            steps {
                sh '''
                    echo "=== Deploy ==="
                    docker run --rm \
                        -v $WORKSPACE:/app \
                        -w /app \
                        williamyeh/ansible:alpine3 \
                        ansible-playbook \
                            -i ansible/inventory.ini \
                            ansible/deploy.yml \
                            -e "image_tag=${IMAGE_TAG}" \
                            -v
                '''
            }
        }
    }

    post {
        success {
            echo "✅ SUCCESS — ${FULL_IMAGE} déployée"
        }
        failure {
            echo "❌ FAILED — vérifier logs"
        }
        always {
            sh 'docker system prune -f || true'
        }
    }
}