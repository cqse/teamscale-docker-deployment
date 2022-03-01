#!/bin/bash
set -e

docker-compose up --remove-orphans --wait --detach $@
./nginx-reload.sh
docker-compose logs --follow --tail=1000