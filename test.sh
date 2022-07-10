#!/bin/bash
set -euo pipefail

# (re)start the test environment in background.
docker compose down
docker compose up --build --detach

# wait for the init service to exit.
while true; do
result="$(docker compose ps --status exited --format json init)"
if [ -n "$result" ] && [ "$result" != 'null' ]; then
    exit_code="$(jq -r '.[].ExitCode' <<<"$result")"
    break
fi
sleep 3
done

# output the init service logs.
docker compose stop
docker compose logs init

# fail with an error when the test failed.
if [ "$exit_code" != "0" ]; then
    echo "ERROR test failed with exit code $exit_code"
    exit 1
fi
