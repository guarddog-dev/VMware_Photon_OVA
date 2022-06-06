##Setup Docker

# Set Versions
USERD="root"
DOCKER_COMPOSE_VERSION="2.3.3"

# Download docker-compose
echo '> Downloading docker-compose...'

curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#Start Docker Services
echo '> Enabling and Starting Docker Services...'
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
sudo systemctl start docker.service
sudo systemctl start containerd.service
sudo systemctl enable docker && systemctl daemon-reload && systemctl restart docker
sudo systemctl status docker.service -l
sudo systemctl status containerd.service -l

#Setup new docker group
echo '> Setting permissions for Docker...'
sudo groupadd docker
#Add user to docker group
sudo usermod -aG docker $USERD
#Setup new group
sudo newgrp docker

#Test Docker Hello World
echo '> Testing Docker World...'
docker run --name hello-world-container hello-world

#Remove Docker Hello World
echo '> Removing Docker Hello World Container...'
docker rm hello-world-container
docker image rm hello-world

#Validate no Docker Containers Remain
echo '> Validating no Docker Containers Remain...'
docker container ls --all

#List Docker Compose Version Post Install
echo '> Listing Docker Version Info...'
docker version
docker-compose --version
