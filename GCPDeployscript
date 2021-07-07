#!/bin/bash

# Update Packages
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install openjdk-8-jdk-headless -y
sudo apt-get install default-jre -y

# Set up Desktop Environment
sudo apt-get install gnome-shell -y
sudo apt-get install ubuntu-gnome-desktop -y
sudo apt-get install autocutsel -y
sudo apt-get install gnome-core -y
sudo apt-get install gnome-panel -y
sudo apt-get install gnome-themes-standard -y

# Install PPA/Git
sudo add-apt-repository ppa:git-core/ppa
sudo apt update -y
sudo apt install git -y

# Set up VNC Server
sudo apt-get install tightvncserver -y
sudo touch ~/.Xresources

# Set Environment Variables - Senzing GH repo
export GIT_ACCOUNT=senzing
export GIT_REPOSITORY=docker-compose-demo
export GIT_ACCOUNT_DIR=~/${GIT_ACCOUNT}.git
export GIT_REPOSITORY_DIR="${GIT_ACCOUNT_DIR}/${GIT_REPOSITORY}"
export GIT_REPOSITORY_URL="https://github.com/${GIT_ACCOUNT}/${GIT_REPOSITORY}.git"

# Install Docker
sudo apt install docker.io -y

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone Synthea GH repo
mkdir --parents ~/synthea.git
cd ~/synthea.git
git clone  --recurse-submodules https://github.com/synthetichealth/synthea.git
cd ~/synthea.git/synthea

# Build and run the test suite (this takes about 15 mins)
./gradlew build check test

# Generate 100 patients for JSON file
./run_synthea -p 100

# Clone senzing GH repo
mkdir --parents ${GIT_ACCOUNT_DIR}
cd  ${GIT_ACCOUNT_DIR}
git clone  --recurse-submodules ${GIT_REPOSITORY_URL}

# Set Environment Variables - Docker/host directories
export SENZING_VOLUME=/opt/my-senzing
export SENZING_DATA_DIR=${SENZING_VOLUME}/data
export SENZING_DATA_VERSION_DIR=${SENZING_DATA_DIR}/2.0.0
export SENZING_ETC_DIR=${SENZING_VOLUME}/etc
export SENZING_G2_DIR=${SENZING_VOLUME}/g2
export SENZING_VAR_DIR=${SENZING_VOLUME}/var
export POSTGRES_DIR=${SENZING_VAR_DIR}/postgres

# Set Environment Variables - Accept Senzing EULA
export SENZING_ACCEPT_EULA="I_ACCEPT_THE_SENZING_EULA"

# Install Senzing
sudo \
  --preserve-env \
  docker-compose --file ~/senzing.git/docker-compose-demo/resources/senzing/docker-compose-senzing-installation.yaml up

# Set Environment Variables - Docker Formation
export SENZING_DOCKER_COMPOSE_FILE=resources/postgresql/docker-compose-kafka-postgresql.yaml

# Install Kafka-Postgres Senzing Infra
sudo \
  --preserve-env \
  docker-compose --file ~/senzing.git/docker-compose-demo/resources/postgresql/docker-compose-kafka-postgresql.yaml up
