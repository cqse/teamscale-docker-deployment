#!/bin/bash

# Script to reload nginx config while running

# If a custom container name is used, adjust here
NGINX_CONTAINER=nginx

# Defaults to use docker-compose, but may also use docker and change to the full container name
DOCKER_CMD=docker-compose

# Check if config file is ok
$DOCKER_CMD exec $NGINX_CONTAINER nginx -t

# By checking the result code of the above command ($?)
if [[ $? -eq 0 ]]; then
    # If yes, reload it and show the last 50 lines in the log
    echo 'Configuration file is ok, reloading...'
    $DOCKER_CMD exec $NGINX_CONTAINER nginx -s reload
    $DOCKER_CMD logs --tail 50 $NGINX_CONTAINER
    echo 'Reloaded configuration'
    exit 0
else
    # Otherwise do nothing
    echo 'There are errors in the conifguration, please resolve them and try again.'
    exit 1
fi
