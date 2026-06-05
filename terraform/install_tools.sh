#!/bin/bash

# Update system and install core packages
# Jenkins LTS (2.5xx+) requires Java 21+ (Java 17 is no longer supported and the
# service fails to start with "older than the minimum required version (Java 21)").
sudo apt update
sudo apt install -y fontconfig openjdk-21-jre

# Jenkins installation
# NOTE: we install the .deb DIRECTLY instead of via the apt repo. On this hardened
# image apt rejected the Jenkins flat repo ("NO_PUBKEY 7198F4B714ABFC68 / not
# signed") even with the correct, current key in a signed-by keyring — apt does not
# reliably honour signed-by for Jenkins' flat (binary/) repo layout. The direct .deb
# needs no repo signing and avoids that whole class of failure across recreates.
JENKINS_VER="$(curl -fsSL https://updates.jenkins.io/stable/latestCore.txt)"
curl -fsSL -o /tmp/jenkins.deb \
  "https://pkg.jenkins.io/debian-stable/binary/jenkins_${JENKINS_VER}_all.deb"
sudo apt-get install -y /tmp/jenkins.deb

# Jenkins won't start out of the box on this image because /tmp is mounted `noexec`
# (corporate hardening). JNA extracts a native .so to the JVM temp dir and maps it
# executable; on noexec /tmp that throws UnsatisfiedLinkError ("failed to map
# segment from shared object") and Jenkins aborts at boot. Fix: give Jenkins an
# exec-allowed temp dir under its home and point java.io.tmpdir (JNA follows it)
# there via a systemd drop-in.
sudo install -d -o jenkins -g jenkins -m 750 /var/lib/jenkins/tmp
sudo mkdir -p /etc/systemd/system/jenkins.service.d
printf '[Service]\nEnvironment="JAVA_OPTS=-Djava.io.tmpdir=/var/lib/jenkins/tmp"\n' \
  | sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins

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
