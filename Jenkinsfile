def hasTerraformChanges(terraformDir) {
  def status = bat(script: "${TERRAFORM_HOME}\\terraform -chdir=${terraformDir} show", returnStatus: true)
  return status != 0
}

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

  stages{
    stage('Terraform Apply (Conditional)') {
        when {
            expression {
            // Run this stage if the initialization directory doesn't exist
            // OR if there are changes in the Terraform configuration
            !fileExists('terraform/.terraform') || hasTerraformChanges('terraform')
            }
        }
        steps {
            script {
            dir('terraform') {
                // Configure Terraform
                echo "Initializing Terraform"
                bat "${TERRAFORM_HOME}\\terraform init"

                // Apply Terraform changes
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
                    dir('terraform'){
                        instanceIPCommand = "${TERRAFORM_HOME}\\terraform output -raw instance_public_ip"
                    }
                    
                    def instanceIPExitStatus = bat(script: instanceIPCommand, returnStatus: true)
                    if (instanceIPExitStatus != 0) {
                        error("Command failed: ${instanceIPCommand}")
                    } else {
                        def instanceIP = bat(script: instanceIPCommand, returnStdout: true).trim()
                        def containerName = "GoApp"

                        // Stop and remove existing container
                        bat """
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ec2-user@${instanceIP} \
                            'docker stop ${containerName} || true' && \
                            ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ec2-user@${instanceIP} \
                            'docker rm ${containerName} || true'
                        """

                        // Pull the latest Docker image and run the container
                        bat """
                            ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${instanceIP} \
                            'docker pull dshwartzman5/go-jenkins-dockerhub-repo:latest' && \
                            ssh -o StrictHostKeyChecking=no -i $SSH_KEY ec2-user@${instanceIP} \
                            'docker run -d -p 8081:8081 --name ${containerName} dshwartzman5/go-jenkins-dockerhub-repo:latest'
                        """
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
