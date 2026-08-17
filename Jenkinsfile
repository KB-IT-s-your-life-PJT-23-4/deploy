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
            choices: ['frontend', 'backend', 'fastapi'],
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

                    case "$SERVICE" in
                        frontend|backend|fastapi) ;;
                        *) echo "지원하지 않는 서비스입니다: $SERVICE" >&2; exit 1 ;;
                    esac

                    if ! printf '%s' "$IMAGE_TAG" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'; then
                        echo "잘못된 Docker 이미지 태그입니다: $IMAGE_TAG" >&2
                        exit 1
                    fi

                    test -f docker-compose.frontend.yml
                    test -f docker-compose.backend.yml
                    test -f nginx/default.conf.template
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
                    string(credentialsId: 'mirizoom-web-host', variable: 'WEB_HOST'),
                    string(credentialsId: 'mirizoom-app-host', variable: 'APP_HOST')
                ]) {
                    sh '''
                        set -eu

                        case "$SERVICE" in
                            frontend)
                                TARGET_HOST="$WEB_HOST"
                                COMPOSE_FILE='docker-compose.frontend.yml'
                                ENV_FILE='frontend.env'
                                COMPOSE_SERVICE='nginx'
                                TAG_VARIABLE='FRONTEND_TAG'
                                ;;
                            backend)
                                TARGET_HOST="$APP_HOST"
                                COMPOSE_FILE='docker-compose.backend.yml'
                                ENV_FILE='app.env'
                                COMPOSE_SERVICE='backend'
                                TAG_VARIABLE='BACKEND_TAG'
                                ;;
                            fastapi)
                                TARGET_HOST="$APP_HOST"
                                COMPOSE_FILE='docker-compose.backend.yml'
                                ENV_FILE='app.env'
                                COMPOSE_SERVICE='fastapi'
                                TAG_VARIABLE='FASTAPI_TAG'
                                ;;
                        esac

                        SSH_TARGET="$SSH_USER@$TARGET_HOST"

                        ssh -i "$SSH_KEY" "$SSH_TARGET" "mkdir -p '$DEPLOY_DIR/nginx'"
                        scp -i "$SSH_KEY" "$COMPOSE_FILE" "$SSH_TARGET:$DEPLOY_DIR/$COMPOSE_FILE"

                        if [ "$SERVICE" = 'frontend' ]; then
                            scp -i "$SSH_KEY" nginx/default.conf.template \
                                "$SSH_TARGET:$DEPLOY_DIR/nginx/default.conf.template"
                        fi

                        ssh -i "$SSH_KEY" "$SSH_TARGET" "
                            set -eu
                            cd '$DEPLOY_DIR'
                            test -f '$ENV_FILE'
                            export $TAG_VARIABLE='$IMAGE_TAG'
                            docker compose --env-file '$ENV_FILE' -f '$COMPOSE_FILE' pull '$COMPOSE_SERVICE'
                            docker compose --env-file '$ENV_FILE' -f '$COMPOSE_FILE' up -d --no-deps '$COMPOSE_SERVICE'
                            docker compose --env-file '$ENV_FILE' -f '$COMPOSE_FILE' ps '$COMPOSE_SERVICE'

                            if grep -q "^$TAG_VARIABLE=" '$ENV_FILE'; then
                                sed -i "s|^$TAG_VARIABLE=.*|$TAG_VARIABLE=$IMAGE_TAG|" '$ENV_FILE'
                            else
                                printf '\n%s=%s\n' '$TAG_VARIABLE' '$IMAGE_TAG' >> '$ENV_FILE'
                            fi
                        "
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
