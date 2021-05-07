#!/bin/bash
(cd nginx; docker-compose up -d)
(cd blue; docker-compose up -d)
(cd green; docker-compose up -d)
