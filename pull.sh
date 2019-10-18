#!/bin/bash

docker exec -it nginx-website bash -c "cd /var/www/html && git pull"