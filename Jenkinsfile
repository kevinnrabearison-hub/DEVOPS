pipeline {
    agent any

    environment {
        IMAGE_NAME     = "mon-api"
        IMAGE_TAG      = "${BUILD_NUMBER}"
        HARBOR_HOST    = "localhost:8081"
        HARBOR_REPO    = "projet"
        FULL_IMAGE     = "${HARBOR_HOST}/${HARBOR_REPO}/${IMAGE_NAME}:${IMAGE_TAG}"
        TRIVY_CACHE    = "/var/jenkins_home/.cache/trivy"
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
    }

    stages {

        // ── Stage 1 : Analyse statique du code ──────────────────────────────
        stage('SAST — Bandit') {
            steps {
                sh '''
                    echo "=== Scan SAST avec Bandit ==="
                    bandit -r src/ \
                        -f txt \
                        -o bandit-report.txt \
                        -ll || true
                    cat bandit-report.txt
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'bandit-report.txt',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 2 : Détection de secrets ──────────────────────────────────
        stage('Secrets — Gitleaks') {
            steps {
                sh '''
                    echo "=== Scan secrets avec Gitleaks ==="
                    docker run --rm \
                        -v "$WORKSPACE":/path \
                        zricethezav/gitleaks:latest \
                        detect \
                        --source /path \
                        --no-git \
                        --report-format json \
                        --report-path /path/gitleaks-report.json \
                        || true
                    echo "Gitleaks terminé"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 3 : Tests unitaires ────────────────────────────────────────
        stage('Tests') {
            steps {
                sh '''
                    echo "=== Tests pytest ==="
                    pip3 install -r requirements.txt \
                                 -r requirements-dev.txt \
                                 --break-system-packages -q
                    python3 -m pytest tests/ -v \
                        --junitxml=test-results.xml \
                        --tb=short
                '''
            }
            post {
                always {
                    junit 'test-results.xml'
                    archiveArtifacts artifacts: 'test-results.xml',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 4 : Scan des dépendances ──────────────────────────────────
        stage('Dependency Scan — pip-audit') {
                    steps {
                        sh '''
                            echo "=== Scan dépendances avec pip-audit ==="
                            pip3 install pip-audit --break-system-packages -q
                            AUDIT=$(find /usr /var/jenkins_home/.local -name "pip-audit" 2>/dev/null | head -1)
                            echo "pip-audit path: $AUDIT"
                            $AUDIT -r requirements.txt \
                                --format text > pip-audit-report.txt 2>&1 || true
                            cat pip-audit-report.txt
                        '''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'pip-audit-report.txt',
                                            allowEmptyArchive: true
                        }
                    }
            }

        // ── Stage 5 : Build de l'image Docker ───────────────────────────────
        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "=== Build image Docker ==="
                    docker build \
                        -f docker/Dockerfile \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \
                        -t ${IMAGE_NAME}:latest \
                        --label "build.number=${BUILD_NUMBER}" \
                        --label "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        .
                    echo "Image buildée : ${IMAGE_NAME}:${IMAGE_TAG}"
                    docker images ${IMAGE_NAME}
                '''
            }
        }

        // ── Stage 6 : Scan de l'image avec Trivy ────────────────────────────
        stage('Scan Image — Trivy') {
            steps {
                sh '''
                    echo "=== Scan image avec Trivy (DB locale) ==="
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --output trivy-report.txt \
                        --exit-code 0 \
                        --skip-db-update \
                        --cache-dir ${TRIVY_CACHE} \
                        ${IMAGE_NAME}:${IMAGE_TAG}
                    echo "=== Résultat Trivy ==="
                    cat trivy-report.txt
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.txt',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 7 : SBOM avec Syft ────────────────────────────────────────
        stage('SBOM — Syft') {
            steps {
                sh '''
                    echo "=== Génération SBOM avec Syft ==="
                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        anchore/syft:latest \
                        ${IMAGE_NAME}:${IMAGE_TAG} \
                        -o table > sbom.txt 2>&1 || true
                    echo "SBOM généré"
                    cat sbom.txt
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'sbom.txt',
                                     allowEmptyArchive: true
                }
            }
        }

        // ── Stage 8 : Push vers Harbor ───────────────────────────────────────
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
                            -u ${HARBOR_USER} \
                            --password-stdin

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${FULL_IMAGE}
                        docker push ${FULL_IMAGE}

                        echo "Image poussée : ${FULL_IMAGE}"
                        docker logout ${HARBOR_HOST}
                    '''
                }
            }
        }

        // ── Stage 9 : Signature Cosign ───────────────────────────────────────
        stage('Sign — Cosign') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-credentials',
                    usernameVariable: 'HARBOR_USER',
                    passwordVariable: 'HARBOR_PASS'
                )]) {
                    sh '''
                        echo "=== Signature image avec Cosign ==="
                        chmod +x scripts/sign.sh
                        HARBOR_USER=${HARBOR_USER} \
                        HARBOR_PASS=${HARBOR_PASS} \
                        HARBOR_HOST=${HARBOR_HOST} \
                            ./scripts/sign.sh ${FULL_IMAGE}
                    '''
                }
            }
        }

        // ── Stage 10 : Vérification Cosign ──────────────────────────────────
        stage('Verify — Cosign') {
            steps {
                sh '''
                    echo "=== Vérification signature Cosign ==="
                    chmod +x scripts/verify.sh
                    ./scripts/verify.sh ${FULL_IMAGE}
                '''
            }
        }

        // ── Stage 11 : Déploiement via Ansible ──────────────────────────────
        stage('Deploy — Ansible') {
            steps {
                sh '''
                    echo "=== Déploiement via Ansible ==="
                    ansible-playbook \
                        -i ansible/inventory.ini \
                        ansible/deploy.yml \
                        -e "image_tag=${IMAGE_TAG}" \
                        -e "full_image=${FULL_IMAGE}" \
                        -e "workspace=${WORKSPACE}" \
                        -v
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline terminé avec succès — ${FULL_IMAGE} déployée"
        }
        failure {
            echo "Pipeline échoué — consulter les logs Jenkins"
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}