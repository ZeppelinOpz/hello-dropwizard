# How to Create Development Environment

## Run Hello-DropWizard Application Localy

To run make commands you need: 

* Install docker-compose 
https://docs.docker.com/compose/install/

* To make sure that you have gnu make

* Add your user account to docker group (run docker commands without sudo)
```bash
 sudo usermod -aG docker $USER
```

Then you can run application & nginx container:

```bash
make run
```

To stop:

```bash
make stop
```

To build:

```bash
make build
```

Run command build the application inside a maven container. You can find the snapshot inside the target folder like you run maven build locally. Because we mount current folder to container. This step is identical with the building step at Jenkins pipeline. With using same container and same build command you can get same output in whole environment. You can fix the error before triggering ci/cd pipeline. And prevent the "code is working on my desktop, but not here" problem.

Run command create 2 container:

* Application container with base maven image
* Nginx container to use as proxy server

```yaml
#docker-compose.yaml
version: "3"
services:
  hello-dropwizard:
    build: 
      context: .
      dockerfile: Dockerfile.app
  nginx:    
    image: nginx
    volumes:
      - ./proxy/conf.d:/etc/nginx/conf.d 
    ports:
      - "8080:80"
```

Application container is created from the file Dockerfile.app

```docker
FROM maven:3.6.0-jdk-11-slim

RUN mkdir -p /var/app/hello-dropwizard
COPY example.yaml /var/app/hello-dropwizard/example.yaml
COPY target/hello-dropwizard-1.0-SNAPSHOT.jar /var/app/hello-dropwizard/.
WORKDIR /var/app/hello-dropwizard/
ENTRYPOINT ["java", "-jar", "hello-dropwizard-1.0-SNAPSHOT.jar", "server", "example.yaml"]

EXPOSE 8080 8081
```

Nginx is used as proxy server the configuration is:

```nginx
#proxy/conf.d/default.conf
server {
    listen 80;
    server_name localhost;
    root /var/www/html;

    location = / {        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://hello-dropwizard:8080/hello-world;          
    }

    location / {        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://hello-dropwizard:8080;          
    }

    location = /hello {
        rewrite /hello /hello-world break;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://hello-dropwizard:8080;
    }

    location = /healthcheck {        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://hello-dropwizard:8081;
    }
}

```

We can see from conf that /hello requests map to /hello-world. Also healthcheck request forwarding to application:8081.

You will also notice that "= /" requests map to /hello-world. This should be need to run healthy environment in elasticbeanstalk because default healthcheck path is /. After application deployment done first time we can update and use /healtcheck path inside configuration options of elasticbeanstalk environment.

## Create Elasticbeanstalk Environments

This stack will create vpc, create a jenkins elasticbeanstalk deployment and create  an application elasticbeanstalk deployment.

### Create Hosted Zone 

Goto aws Route53 and create a empty hosted zone

Take note the id of zone

### Create Token With Public Access For Jenkins

https://github.com/ZeppelinOpz/jenkins

![Alt text](images/token.png?raw=true "Title")

Take note the token

### Create Vpc

Goto vpc directory

Upadate the variables inside main.tf

- your_aws_profile

 Run :

```bash
terraform init
terraform apply
```

Take note of the vpc.id , public subnets id , private subnets id from output

### Create Jenkins

Goto jenkins directory

Upadate the variables inside main.tf

- your_aws_profile
- your_vpc_id
- your_rout53_hosted_zone_id
- your_public_subnet_* (1,2,3) 
- your_private_subnet_* (1,2,3)
- github_* (jenkins docker repository settings & token)

```bash
module "jenkins" {
  source      = "./modules/terraform-aws-jenkins"
  namespace   = "cp"
  name        = "jenkins"
  stage       = "dev"
  description = "Jenkins server as Docker container running on Elastic Beanstalk"

  master_instance_type         = "t2.large"
  aws_account_id               = ""
  aws_region                   = "us-east-1"
  availability_zones           = ["${slice(data.aws_availability_zones.available.names, 0, var.max_availability_zones)}"]
  vpc_id                       = "your_vpc_id"
  zone_id                      = "your_rout53_hosted_zone_id"
  public_subnets               = ["your_public_subnet_1","your_public_subnet_2","your_public_subnet_3"]
  private_subnets              = ["your_private_subnet_1","your_private_subnet_2","your_private_subnet_2"]
  loadbalancer_certificate_arn = ""
  ssh_key_pair                 = "${aws_key_pair.generated_key.key_name}"

  root_volume_size = "100"
  root_volume_type = "standard"

  github_oauth_token  = "put git_public_access_token"
  github_organization = "ZeppelinOpz"
  github_repo_name    = "jenkins"
  github_branch       = "master"

  datapipeline_config = {
    instance_type = "t2.medium"
    email         = "rtinoco@zeppelinops.com"
    period        = "12 hours"
    timeout       = "60 Minutes"
  }

  env_vars = {
    JENKINS_USER          = "admin"
    JENKINS_PASS          = "start12!"
    JENKINS_NUM_EXECUTORS = 4
  }

  tags = {
    BusinessUnit = "Build"
    Department   = "Ops"
  }
}
```

 Run :

```bash
terraform init
terraform apply
```

### Create Environments 

Goto environments/example directory

Upadate the variables inside main.tf

- your_aws_profile
- your_vpc_id
- your_rout53_hosted_zone_id
- your_public_subnet_* (1,2,3) 
- your_private_subnet_* (1,2,3)


```bash
module "elasticbeanstalk-demo" {
  source      = "../"
  namespace   = "ops"
  name        = "hello-dropwizard"
  stage       = "app"
  description = "Demo application as Multi Docker container running on Elastic Beanstalk"

  master_instance_type         = "t2.small"
  aws_account_id               = ""
  aws_region                   = "us-east-1"
  availability_zones           = ["${slice(data.aws_availability_zones.available.names, 0, var.max_availability_zones)}"]
  vpc_id                       = "vpc-id"
  zone_id                      = "zone-id"
  public_subnets               = ["public_subnet_1","public_subnet_2","public_subnet_3"]
  private_subnets              = ["private_subnet_1","private_subnet_2","private_subnet_3"]
  loadbalancer_certificate_arn = ""
  ssh_key_pair                 = "${aws_key_pair.generated_key.key_name}"
  solution_stack_name          = "64bit Amazon Linux 2018.03 v2.11.6 running Multi-container Docker 18.06.1-ce (Generic)"

  env_vars = {
  }

  tags = {
    BusinessUnit = "Demo"
    Department   = "Ops"
    Environment  = "Development"
  }
}

```

 Run :

```bash
terraform init
terraform apply
```


### Setup Jenkins

After jenkins elasticbeanstalk environment created. Login jenkins with default credentials admin/start12!

You can examine the steps that we are using in pipeline inside the Jenkinsfile. We have 3 steps:

```groovy
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
```

```nginx
* We run mvn package within same image like our local environment

* We build & tag docker image using Dockerfile.app

* We pushed new image to docker hub with tagged git commit-id

* Then we create & update elasticbeanstalk application version using aws commands
```



* Click credentials and add new credential

![Alt text](images/add-credentials.png?raw=true "Title")

* Save docker hub credentials with id docker-hub. Which will be using our image repository for dropwizard application.

![Alt text](images/save-credentials.png?raw=true "Title")

* Click Open Blue Ocean

![Alt text](images/blueocean.png?raw=true "Title")

* Click Create a new Pipeline

![Alt text](images/create-pipeline.png?raw=true "Title")

* Create access token from github and import hello-dropwizard repository

![Alt text](images/pipeline-done.png?raw=true "Title")

# How to Remove

Delete all buckets created with above steps

* First get all buckets

```bash
aws s3 ls | cut -d" " -f 3 > buckets
```

* Modify buckets file, remove the bucket name you want to keep

* Delete buckets

```bash
cat buckets | xargs -I{} aws s3 rb s3://{} --force
```

Then run:

```
terraform destroy
```

for in order : environments,jenkins,vpc