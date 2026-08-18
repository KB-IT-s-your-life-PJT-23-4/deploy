#!/usr/bin/env bash

set -Eeuo pipefail

SERVICE="${1:?서비스 인자가 필요합니다.}"
IMAGE_TAG="${2:?이미지 태그 인자가 필요합니다.}"
DEPLOY_DIR="${3:-/opt/mirizoom}"

case "$SERVICE" in
    frontend)
        COMPOSE_FILE='docker-compose.frontend.yml'
        ENV_FILE='frontend.env'
        COMPOSE_SERVICE='nginx'
        TAG_VARIABLE='FRONTEND_TAG'
        ;;

    backend)
        COMPOSE_FILE='docker-compose.backend.yml'
        ENV_FILE='app.env'
        COMPOSE_SERVICE='backend'
        TAG_VARIABLE='BACKEND_TAG'
        ;;

    fastapi)
        COMPOSE_FILE='docker-compose.backend.yml'
        ENV_FILE='app.env'
        COMPOSE_SERVICE='fastapi'
        TAG_VARIABLE='FASTAPI_TAG'
        ;;

    *)
        echo "지원하지 않는 서비스입니다: $SERVICE" >&2
        exit 1
        ;;
esac

if ! printf '%s' "$IMAGE_TAG" |
    grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'
then
    echo "잘못된 Docker 이미지 태그입니다: $IMAGE_TAG" >&2
    exit 1
fi

cd "$DEPLOY_DIR"

test -f "$COMPOSE_FILE"
test -f "$ENV_FILE"

TEMP_ENV="$(mktemp "${ENV_FILE}.XXXXXX")"

cleanup() {
    rm -f "$TEMP_ENV"
}

trap cleanup EXIT

cp "$ENV_FILE" "$TEMP_ENV"

if grep -q "^${TAG_VARIABLE}=" "$TEMP_ENV"; then
    sed -i \
        "s|^${TAG_VARIABLE}=.*|${TAG_VARIABLE}=${IMAGE_TAG}|" \
        "$TEMP_ENV"
else
    printf '\n%s=%s\n' \
        "$TAG_VARIABLE" \
        "$IMAGE_TAG" >> "$TEMP_ENV"
fi

echo "${SERVICE}:${IMAGE_TAG} 이미지 Pull"

docker compose \
    --env-file "$TEMP_ENV" \
    -f "$COMPOSE_FILE" \
    pull "$COMPOSE_SERVICE"

echo "${SERVICE}:${IMAGE_TAG} 컨테이너 적용"

docker compose \
    --env-file "$TEMP_ENV" \
    -f "$COMPOSE_FILE" \
    up -d --no-deps "$COMPOSE_SERVICE"

docker compose \
    --env-file "$TEMP_ENV" \
    -f "$COMPOSE_FILE" \
    ps "$COMPOSE_SERVICE"

mv "$TEMP_ENV" "$ENV_FILE"
trap - EXIT

echo "${SERVICE}:${IMAGE_TAG} 배포 완료"