#!/bin/bash

# Script to reload nginx config while running

# Check if config file is ok
docker exec nginx_nginx_1 nginx -t

# By checking the result code of the above command ($?)
if [[ $? -eq 0 ]]; then
    # If yes, reload it and show the last 50 lines in the log
    echo 'Configuration file is ok, reloading...'
    docker exec -it nginx_nginx_1 nginx -s reload
    docker logs --tail 50 nginx_nginx_1 
    echo 'Reloaded configuration'
    exit 0
else
    # Otherwise do nothing
    echo 'There are errors in the conifguration, please resolve them and try again.'
    exit 1
fi
