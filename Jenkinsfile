pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
        timeout(time: 15, unit: 'MINUTES')
        timestamps()
    }

    parameters {
        choice(
            name: 'SERVICE',
            choices: ['frontend', 'backend', 'fastapi', 'batch'],
            description: '배포할 서비스'
        )

        string(
            name: 'IMAGE_TAG',
            defaultValue: 'latest',
            description: 'Docker Hub에 Push된 이미지 태그'
        )
    }

    environment {
        DEPLOY_DIR = '/opt/mirizoom'
        DEPLOY_SERVICE = "${params.SERVICE ?: 'frontend'}"
        DEPLOY_IMAGE_TAG = "${params.IMAGE_TAG ?: 'latest'}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate') {
            steps {
                sh '''
                    set -eu

                    case "$DEPLOY_SERVICE" in
                        frontend|backend|fastapi|batch)
                            ;;
                        *)
                            echo "지원하지 않는 서비스입니다: $DEPLOY_SERVICE" >&2
                            exit 1
                            ;;
                    esac

                    if ! printf '%s' "$DEPLOY_IMAGE_TAG" |
                        grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
                    then
                        echo "잘못된 이미지 태그입니다: $DEPLOY_IMAGE_TAG" >&2
                        exit 1
                    fi

                    test -f docker-compose.frontend.yml
                    test -f docker-compose.backend.yml
                    test -f nginx/default.conf.template
                    test -f scripts/deploy-service.sh

                    echo "배포 서비스: $DEPLOY_SERVICE"
                    echo "이미지 태그: $DEPLOY_IMAGE_TAG"
                '''
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'mirizoom-ec2-ssh',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    ),
                    string(
                        credentialsId: 'mirizoom-web-host',
                        variable: 'WEB_HOST'
                    ),
                    string(
                        credentialsId: 'mirizoom-app-host',
                        variable: 'APP_HOST'
                    )
                ]) {
                    sh '''
                        set -eu

                        case "$DEPLOY_SERVICE" in
                            frontend)
                                TARGET_HOST="$WEB_HOST"
                                COMPOSE_FILE='docker-compose.frontend.yml'
                                ;;

                            backend|fastapi|batch)
                                TARGET_HOST="$APP_HOST"
                                COMPOSE_FILE='docker-compose.backend.yml'
                                ;;
                        esac

                        SSH_TARGET="$SSH_USER@$TARGET_HOST"

                        echo "배포 대상: $SSH_TARGET"

                        ssh \
                            -o BatchMode=yes \
                            -o ConnectTimeout=10 \
                            -o StrictHostKeyChecking=yes \
                            -i "$SSH_KEY" \
                            "$SSH_TARGET" \
                            "mkdir -p '$DEPLOY_DIR/nginx' '$DEPLOY_DIR/scripts'"

                        scp \
                            -o BatchMode=yes \
                            -o ConnectTimeout=10 \
                            -o StrictHostKeyChecking=yes \
                            -i "$SSH_KEY" \
                            "$COMPOSE_FILE" \
                            "$SSH_TARGET:$DEPLOY_DIR/$COMPOSE_FILE"

                        scp \
                            -o BatchMode=yes \
                            -o ConnectTimeout=10 \
                            -o StrictHostKeyChecking=yes \
                            -i "$SSH_KEY" \
                            scripts/deploy-service.sh \
                            "$SSH_TARGET:$DEPLOY_DIR/scripts/deploy-service.sh"

                        if [ "$DEPLOY_SERVICE" = 'frontend' ]; then
                            scp \
                                -o BatchMode=yes \
                                -o ConnectTimeout=10 \
                                -o StrictHostKeyChecking=yes \
                                -i "$SSH_KEY" \
                                nginx/default.conf.template \
                                "$SSH_TARGET:$DEPLOY_DIR/nginx/default.conf.template"
                        fi

                        ssh \
                            -o BatchMode=yes \
                            -o ConnectTimeout=10 \
                            -o StrictHostKeyChecking=yes \
                            -i "$SSH_KEY" \
                            "$SSH_TARGET" \
                            "chmod 700 '$DEPLOY_DIR/scripts/deploy-service.sh' && \
                             '$DEPLOY_DIR/scripts/deploy-service.sh' \
                             '$DEPLOY_SERVICE' \
                             '$DEPLOY_IMAGE_TAG' \
                             '$DEPLOY_DIR'"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "${params.SERVICE}:${params.IMAGE_TAG} 배포가 완료되었습니다."
        }

        failure {
            echo "${params.SERVICE}:${params.IMAGE_TAG} 배포에 실패했습니다."
        }

        cleanup {
            deleteDir()
        }
    }
}
