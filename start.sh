#!/bin/bash
set -e

docker compose up --remove-orphans --detach $@
./nginx-reload.sh
docker compose logs --follow --tail=100