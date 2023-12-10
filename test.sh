#!/bin/bash
set -euo pipefail

# destroy the existing environment.
echo "destroying the existing environment..."
docker compose down --volumes --remove-orphans

# start the environment in background.
echo "creating the environment..."
docker compose up --build --detach

# wait for the init and test services to exit.
function wait-for-service {
    echo "waiting for the $1 service to exit..."
    while true; do
        result="$(docker compose ps --status exited --format json $1)"
        if [ -n "$result" ] && [ "$result" != 'null' ]; then
            exit_code="$(jq -r '.[].ExitCode' <<<"$result")"
            break
        fi
        sleep 3
    done
    docker compose logs $1
    return $exit_code
}
wait-for-service init
wait-for-service test
