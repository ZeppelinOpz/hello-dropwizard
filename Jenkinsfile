pipeline {
  agent any
  stages {
    stage('Build & Deploy') {
      stages {
        stage('Build-Development') {          
          when {
            branch 'development'
          }
          agent { 
            docker { 
              image 'maven:3.6.0-jdk-11-slim'
              args '--entrypoint="" -v $HOME/.m2:/root/.m2'
            }
          }
          steps {
            ws("/var/jenkins/hello-dropwizard-${BRANCH_NAME}-${GIT_COMMIT}") {
              checkout scm                      
              sh 'mvn package'              
            }
          }
        }      
        stage('Create-Image') {
          when {
            branch 'development'
          }
          agent {
            docker { 
              image 'docker/compose:1.21.0'
              args '--entrypoint=""'
            }
          }          
          steps {
            ws("/var/jenkins/hello-dropwizard-${BRANCH_NAME}-${GIT_COMMIT}") {
              withDockerRegistry(credentialsId: 'docker-hub', url: 'https://index.docker.io/v1/') {
                sh "docker build . -t hello-dropwizard-${BRANCH_NAME}:${GIT_COMMIT} -f Dockerfile.app"
                sh "docker tag hello-dropwizard-${BRANCH_NAME}:${GIT_COMMIT} zeppelinops/hello-dropwizard-${BRANCH_NAME}:${GIT_COMMIT}"
                sh "docker tag hello-dropwizard-${BRANCH_NAME}:${GIT_COMMIT} zeppelinops/hello-dropwizard-${BRANCH_NAME}:latest"
                sh "docker push zeppelinops/hello-dropwizard-${BRANCH_NAME}:${GIT_COMMIT}"
                sh "docker push zeppelinops/hello-dropwizard-${BRANCH_NAME}:latest"
                sh 'test ! -z "$(docker images -q zeppelinops/aws:latest)" &&  docker rmi zeppelinops/aws:latest'
              }
            }                        
          }
        }
        stage('Deploy-Development') {
          when {
            branch 'development'
          }          
          agent {
            docker { 
              image 'zeppelinops/aws:latest'
              args '--entrypoint=""'
            }
          }          
          steps {
            ws("/var/jenkins/hello-dropwizard-${BRANCH_NAME}-${GIT_COMMIT}") {
              sh "envsubst < Dockerrun.aws.json.template > Dockerrun.aws.json"
              sh "zip -r -j zeppelinops-hello-dropwizard-app-${GIT_COMMIT}.zip Dockerrun.aws.json"
              sh "zip -r zeppelinops-hello-dropwizard-app-${GIT_COMMIT}.zip proxy/*"                           
              sh "aws s3 mb s3://zeppelinops-hello-dropwizard-app --region us-east-1"
              sh "aws s3 cp zeppelinops-hello-dropwizard-app-${GIT_COMMIT}.zip s3://zeppelinops-hello-dropwizard-app --region us-east-1"  
              sh '''
                aws elasticbeanstalk create-application-version --application-name ops-app-hello-dropwizard \
                --version-label "development-${GIT_COMMIT}" \
                --source-bundle S3Bucket="zeppelinops-hello-dropwizard-app",S3Key="zeppelinops-hello-dropwizard-app-${GIT_COMMIT}.zip" --region us-east-1
              '''
              sh '''
                aws elasticbeanstalk update-environment --application-name ops-app-hello-dropwizard \
                --environment-name ops-app-hello-dropwizard-development \
                --version-label "development-${GIT_COMMIT}" --region us-east-1
              '''               
            }                        
          }
        }  
      }      
    }
  }
}