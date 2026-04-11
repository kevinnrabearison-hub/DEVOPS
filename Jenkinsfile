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
                    bandit -r src/ -f txt -o bandit-report.txt || true
                    cat bandit-report.txt
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
                    docker run --rm -v $(pwd):/path \
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

stage('Tests') {
    steps {
        sh '''
            docker run --rm \
                -v $(pwd):/app \
                -w /app \
                python:3.13-slim \
                sh -c "
                    pip install -r requirements.txt -r requirements-dev.txt &&
                    python -m pytest tests/ -v \
                        --junitxml=test-results.xml \
                        --cov=src --cov-report=xml
                "
        '''
    }
}

        stage('Dependency Scan') {
            steps {
                sh '''
                    echo "=== Safety scan ==="
                    pip install safety
                    safety check -r requirements.txt || true
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

        stage('Scan Image — Trivy (STRICT)') {
            steps {
                sh '''
                    echo "=== Trivy scan ==="
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        --no-progress \
                        ${IMAGE_NAME}:${IMAGE_TAG}
                '''
            }
        }

        stage('SBOM') {
            steps {
                sh '''
                    echo "=== SBOM (Syft) ==="
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
                    chmod +x scripts/sign.sh
                    ./scripts/sign.sh ${FULL_IMAGE}
                '''
            }
        }

        stage('Verify Image') {
            steps {
                sh '''
                    chmod +x scripts/verify.sh
                    ./scripts/verify.sh ${FULL_IMAGE}
                '''
            }
        }

        stage('Deploy — Ansible') {
            steps {
                sh '''
                    echo "=== Deploy ==="
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