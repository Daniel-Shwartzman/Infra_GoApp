def instancePublicIp

pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = 'docker-credentials'
        DOCKER_ACCESS_TOKEN = credentials('docker-credentials')
        DOCKER_USERNAME = 'dshwartzman5'
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        TERRAFORM_HOME = tool 'terraform'
    }

    stages {
        stage('Terraform Apply (Conditional)') {
            steps {
                script {
                    dir('terraform') {
                        echo "Initializing Terraform"
                        bat "${TERRAFORM_HOME}\\terraform init -input=false"
                        echo "Applying Terraform changes"
                        bat "${TERRAFORM_HOME}\\terraform apply -auto-approve"
                        echo "Fetching instance public IP"
                        def output = bat(script: "${TERRAFORM_HOME}\\terraform output -raw instance_public_ip", returnStdout: true).trim()
                        def matcher = (output =~ /\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3})\b/)
                        if (matcher.matches()) {
                        instancePublicIp = matcher[0][0]
                        echo "Instance Public IP: ${instancePublicIp}"
                        } else {
                            error "Failed to extract instance public IP"
                        }

                    }
                }
            }
        }

        stage('Deploy Container') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY_FILE', passphraseVariable: '', usernameVariable: 'SSH_USERNAME')]) {
                        def containerName = "GoApp"

                        // Check if the container exists and stop/remove if it does
                        bat "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_FILE} ${SSH_USERNAME}@${instancePublicIp} \"docker ps -q --filter name=${containerName} | xargs docker stop 2>1 && docker ps -q --filter name=${containerName} | xargs docker rm 2>1\""

                        // Pull the latest Docker image and run the container
                        bat "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_FILE} ${SSH_USERNAME}@${instancePublicIp} \"docker pull dshwartzman5/go-jenkins-dockerhub-repo:latest && docker run -d -p 8081:8081 --name ${containerName} dshwartzman5/go-jenkins-dockerhub-repo:latest\""
                    }
                }
            }
        }

        stage('Cleanup') {
            steps {
                cleanWs()
            }
        }
    }

    post {
        always {
            withCredentials([string(credentialsId: 'discord-credential', variable: 'WEBHOOK_URL')]) {
                script {
                    def buildStatus = currentBuild.currentResult
                    def buildStatusMessage = buildStatus == 'SUCCESS' ? 'CD Succeeded' : 'CD Failed'
                    discordSend description: buildStatusMessage, link: env.BUILD_URL, result: buildStatus, title: JOB_NAME, webhookURL: WEBHOOK_URL
                }
            }
        }
    }
}