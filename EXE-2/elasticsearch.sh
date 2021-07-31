#!/bin/bash

sudo apt-get install curl -y

curl -fsSL https://get.docker.com -o get-docker.sh

sudo sh get-docker.sh

docker --version

sleep 2s

docker run -d -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" docker.elastic.co/elasticsearch/elasticsearch:7.13.4

