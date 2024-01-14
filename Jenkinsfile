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
                        bat "${TERRAFORM_HOME}\\terraform init -input=false -migrate-state""
                        echo "Applying Terraform changes"
                        bat "${TERRAFORM_HOME}\\terraform apply -auto-approve"
                    }
                }
            }
        }

        stage('Deploy Container') {
            steps {
                script {
                    withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY_FILE', passphraseVariable: '', usernameVariable: 'SSH_USERNAME')]) {
                        // Fetch the state file from S3
                        def stateFile = bat(script: "aws s3 cp s3://terraform-backend-go-app/network/ -", returnStdout: true).trim()

                        // Parse the state file to get the instance public IP
                        def terraformOutput = readJSON text: stateFile
                        def instancePublicIp = terraformOutput.modules[0].resources["aws_instance.Go-App"].primary.attributes.public_ip

                        if (instancePublicIp.isEmpty()) {
                            error "Failed to retrieve a valid Terraform output for instance_public_ip."
                        }

                        def containerName = "GoApp"

                        // Check if the container exists and stop/remove if it does
                        bat "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_FILE} ${SSH_USERNAME}@${instancePublicIp} 'docker ps -q --filter name=${containerName} | xargs docker stop 2>1 && docker ps -q --filter name=${containerName} | xargs docker rm 2>1'"

                        // Pull the latest Docker image and run the container
                        bat "ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_FILE} ${SSH_USERNAME}@${instancePublicIp} 'docker pull dshwartzman5/go-jenkins-dockerhub-repo:latest && docker run -d -p 8081:8081 --name ${containerName} dshwartzman5/go-jenkins-dockerhub-repo:latest'"
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
