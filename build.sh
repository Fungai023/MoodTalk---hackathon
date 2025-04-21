#!/bin/bash
# A simple script to set up MoodTalk hackathon environment

set -e  # Stop script on first error

dirname=".npm-global"
currentDir=$(pwd)
justPath="/home/princess/Hakhathon/MoodTalk---hackathon"

echo "==== Starting MoodTalk Environment Setup ===="


# Docker Setup
echo ">> Checking Docker..."

# Check if Docker CLI is installed
if command -v docker &> /dev/null; then
    echo "✅ Docker CLI is already installed. Skipping installation."
else
    echo "🚨 Docker CLI is not installed. Proceeding with installation."

    # Get Ubuntu version number
    ubuntu_version=$(lsb_release -rs)
    ubuntu_major_minor=$(echo "$ubuntu_version" | awk -F. '{printf "%d%02d", $1, $2}')

    if [ "$ubuntu_major_minor" -ge 2204 ]; then
        echo "🛠 Ubuntu $ubuntu_version detected. Installing Docker CLI..."

        # Install Docker CLI
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg lsb-release

        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        sudo groupadd docker || true
        sudo usermod -aG docker "$USER"
        newgrp docker

        echo "✅ Docker CLI installed successfully."
    else
        echo "🛠 Ubuntu $ubuntu_version detected. Installing Docker Desktop, KVM, and Docker CLI..."

        # Install Docker Desktop
        sudo apt update
        sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release gnome-terminal

        curl -LO https://desktop.docker.com/linux/main/amd64/docker-desktop-4.30.0-amd64.deb
        sudo apt install -y ./docker-desktop-4.30.0-amd64.deb
        rm docker-desktop-4.30.0-amd64.deb
        systemctl --user start docker-desktop
        sudo docker compose version
        sudo docker --version
        sudo docker version

        systemctl --user enable docker-desktop

        echo "✅ Docker Desktop installed successfully."

        # Set up KVM virtualization support
        modprobe kvm
        modprobe kvm_intel  # Intel processors
        modprobe kvm_amd    # AMD processors
        kvm-ok
        lsmod | grep kvm
        ls -al /dev/kvm
        sudo usermod -aG kvm $USER
    fi
fi


echo ">> Checking Java and Maven installation..."

# Check if Java is installed and the version is 21
if java -version 2>&1 | grep '21' &> /dev/null; then
    echo "✅ Java 21 is already installed. Skipping installation."
else
    echo "⏬ Installing Java 21..."
    sudo apt update
    sudo apt install -y openjdk-21-jdk
fi


# Check if Maven is installed
if command -v mvn &> /dev/null; then
    echo "✅ Maven is already installed. Skipping installation."
else
    echo "⏬ Installing Maven..."
    sudo apt update
    sudo apt install -y maven
fi


# Hosts entries for reverse proxy
echo ">> Setting up local reverse proxy mappings..."
cd "$currentDir/MoodTalk---hackathon/apps"
if [ -d "/.apps" ]; then
    if [ "$(basename "$pwd")" = "$justPath" ]; then
        cd reverse_proxy
    fi
fi

sudo sh -c 'cat << EOF >> /etc/hosts
127.0.0.1 app.planner.localhost
127.0.0.1 idp.planner.localhost
127.0.0.1 id.planner.localhost
127.0.0.1 api.planner.localhost
127.0.0.1 static.planner.localhost
127.0.0.1 mailhog.planner.localhost
::1 app.planner.localhost
::1 idp.planner.localhost
::1 id.planner.localhost
::1 api.planner.localhost
::1 static.planner.localhost
::1 mailhog.planner.localhost
EOF'

# Step into the project root
echo ">> Verifying IDP extension..."
cd ..
if [ -d "/.apps" ]; then
    if [ "$(basename "$pwd")" = "$justPath" ]; then
          cd idp
          mvn -B verify --file extensions/pom.xml
    fi
fi


# Start Docker containers
echo ">> Running docker-compose..."
sudo docker-compose up -d

# UI Setup
echo ">> Setting up front-end dependencies..."
cd ..
if [ -d "/.apps" ]; then
    if [ "$(basename "$pwd")" = "$justPath" ]; then
        cd ui
    fi
fi

npm install
npm ci
#npm install @openapitools/openapi-generator-cli -D
sudo npm install -g @openapitools/openapi-generator-cli
npx openapi-generator-cli version-manager set 7.6.0
npm run prebuild


# Angular config
my_angular_configuration() {
    echo ">> Configuring Angular CLI..."
    npm config set prefix '~/.npm-global'
    export PATH="$HOME/.npm-global/bin:$PATH"
    source ~/.bashrc   # or ~/.zshrc
    npm install -g @angular/cli
    ng serve
}


if [ -d "$HOME/$dirname" ]; then
    echo ">> Angular CLI directory exists."
    my_angular_configuration
else
    echo ">> Creating Angular CLI directory..."
    mkdir -p "$HOME/$dirname"
    my_angular_configuration
fi


# Back-end Setup
echo ">> Compiling and running backend service..."
cd ..
if [ -d "/.apps" ]; then
    if [ "$(basename "$pwd")" = "$justPath" ]; then
        cd svc
    fi
fi


mvn clean install -DskipTests
mvn spring-boot:run   # NOTE: Keycloak must be up for this to work

echo "==== MoodTalk Setup Complete ===="

