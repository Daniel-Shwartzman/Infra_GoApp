pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = 'docker-credentials'
        DOCKER_ACCESS_TOKEN = credentials('docker-credentials')
        DOCKER_USERNAME = 'dshwartzman5'
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        TERRAFORM_HOME = tool 'Terraform_31130_windows_amd64'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Apply (Conditional)') {
            steps {
                script {
                    dir('terraform') {
                        echo "Refreshing Terraform state"
                        bat "${TERRAFORM_HOME}\\terraform apply -refresh-only -auto-approve"
                        echo "Initializing Terraform"
                        bat "${TERRAFORM_HOME}\\terraform init"
                        echo "Applying Terraform changes"
                        bat "${TERRAFORM_HOME}\\terraform apply -auto-approve"
                    }
                }
            }
        }

        stage('Deploy Container') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'ec2-ssh-key', variable: 'SSH_KEY')]) {
                        def terraformOutput = bat(script: "${TERRAFORM_HOME}\\terraform output -raw instance_public_ip", returnStatus: true).trim()

                        if (terraformOutput) {
                            def containerName = "GoApp"

                            // Stop and remove existing container
                            bat "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ec2-user@${terraformOutput} 'docker stop ${containerName} || true && docker rm ${containerName} || true'"

                            // Pull the latest Docker image and run the container
                            bat "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ec2-user@${terraformOutput} 'docker pull dshwartzman5/go-jenkins-dockerhub-repo:latest && docker run -d -p 8081:8081 --name ${containerName} dshwartzman5/go-jenkins-dockerhub-repo:latest'"
                        } else {
                            error "Failed to retrieve the Terraform output for instance_public_ip."
                        }
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
