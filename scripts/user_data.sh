#!/bin/bash

# Install Docker
sudo yum -y update
sudo yum -y install docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user
newgrp docker
