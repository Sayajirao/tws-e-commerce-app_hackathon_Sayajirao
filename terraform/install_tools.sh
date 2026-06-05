#!/bin/bash

# Update system and install core packages
sudo apt update
sudo apt install -y fontconfig openjdk-17-jre

# Jenkins installation
# NOTE: the old `jenkins.io-2023.key` file expired 2026-03-26 and Jenkins rotated
# their APT signing key (current id 7198F4B714ABFC68). Pull the current key from a
# keyserver into a dedicated keyring so this keeps working across recreates.
sudo gpg --batch --yes --no-default-keyring \
  --keyring /usr/share/keyrings/jenkins-keyring.gpg \
  --keyserver keyserver.ubuntu.com --recv-keys 7198F4B714ABFC68
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get -y install jenkins

sudo systemctl start jenkins
sudo systemctl enable jenkins

# Docker installation
sudo apt-get update
sudo apt-get install docker.io -y

# User group permission
sudo usermod -aG docker $USER
sudo usermod -aG docker jenkins

sudo systemctl restart docker
sudo systemctl restart jenkins

# Install dependencies and Trivy
# Use a dedicated keyring (apt-key is deprecated) and `tee` (overwrite, not `-a`
# append) so the repo line isn't duplicated on every boot / recreate.
sudo apt-get install wget apt-transport-https gnupg lsb-release snapd -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | sudo gpg --dearmor -o /usr/share/keyrings/trivy-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy-keyring.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null
sudo apt-get update -y
sudo apt-get install trivy -y

# AWS CLI installation
sudo snap install aws-cli --classic

# Helm installation
sudo snap install helm --classic

# Kubectl installation (handy for interacting with EKS from this box)
sudo snap install kubectl --classic
