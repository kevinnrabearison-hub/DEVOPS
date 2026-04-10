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
                    echo "=== Scan du code source avec Bandit ==="
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
                    echo "=== Scan des secrets avec Gitleaks ==="
                    docker run --rm \
                        -v $(pwd):/path \
                        zricethezav/gitleaks:latest \
                        detect --source /path --no-git \
                        --report-format json \
                        --report-path /path/gitleaks-report.json \
                        || true
                    echo "Scan Gitleaks terminé"
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
                    echo "=== Lancement des tests pytest ==="
                    pip3 install -r requirements.txt -r requirements-dev.txt \
                        --break-system-packages -q
                    python3 -m pytest tests/ -v \
                        --junitxml=test-results.xml
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }

        stage('Build image Docker') {
            steps {
                sh '''
                    echo "=== Build de l image Docker ==="
                    docker build \
                        -f docker/Dockerfile \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${IMAGE_NAME}:latest \
                        .
                    echo "Image buildée : ${IMAGE_NAME}:${IMAGE_TAG}"
                '''
            }
        }

        stage('Scan image — Trivy') {
            steps {
                sh '''
                    echo "=== Scan de l image avec Trivy ==="
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --output trivy-report.txt \
                        --exit-code 0 \
                        ${IMAGE_NAME}:${IMAGE_TAG}
                    cat trivy-report.txt
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
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
                        echo "=== Push vers Harbor ==="
                        echo "${HARBOR_PASS}" | docker login ${HARBOR_HOST} \
                            -u ${HARBOR_USER} --password-stdin
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE}
                        docker push ${FULL_IMAGE}
                        echo "Image poussée : ${FULL_IMAGE}"
                    '''
                }
            }
        }

        stage('Déploiement — Ansible') {
            steps {
                sh '''
                    echo "=== Déploiement via Ansible ==="
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
            echo "Pipeline terminé avec succès — image ${FULL_IMAGE} déployée"
        }
        failure {
            echo "Pipeline échoué — vérifier les logs"
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
