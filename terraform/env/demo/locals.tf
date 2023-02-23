locals {
  name = "demo-mudi"
  ecs_user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${local.name} >> /etc/ecs/ecs.config
  EOF
  jenkins_user_data = <<-EOT
  #!/bin/bash
  set -x
  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
  workdir="/home/ec2-user"
  cd $workdir
  sudo yum update -y
  sudo yum install java-17-amazon-corretto-headless java-openjdk11 -y
  sudo yum install -y git docker jq
  sudo curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest
  sudo tee /etc/yum.repos.d/jenkins.repo<<EOF
  [jenkins]
  name=Jenkins
  baseurl=http://pkg.jenkins.io/redhat
  gpgcheck=0
  EOF
  sudo rpm --import https://jenkins-ci.org/redhat/jenkins-ci.org.key
  sudo yum repolist
  sudo yum install jenkins -y
  sudo systemctl start jenkins
  sudo systemctl enable jenkins
  admin_pass=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
  sudo wget http://localhost:8080/jnlpJars/jenkins-cli.jar
  plugins="javax-activation-api ws-cleanup javax-mail-api jjwt-api sshd cloudbees-folder antisamy-markup-formatter structs ant workflow-step-api token-macro build-timeout handlebars credentials trilead-api workflow-cps ssh-credentials plain-credentials workflow-job credentials-binding momentjs scm-api workflow-api timestamper caffeine-api script-security mailer plugin-util-api font-awesome-api popper-api jsch jquery3-api workflow-basic-steps bootstrap4-api snakeyaml-api jackson2-api git-client popper2-api gradle bootstrap5-api echarts-api pipeline-milestone-step display-url-api workflow-support git-server checks-api junit matrix-project pipeline-input-step resource-disposer durable-task workflow-scm-step workflow-durable-task-step branch-api jdk-tool command-launcher pipeline-stage-step bouncycastle-api ace-editor apache-httpcomponents-client-4-api role-strategy pipeline-graph-analysis pipeline-rest-api pipeline-stage-view pipeline-build-step pipeline-model-api pipeline-model-extensions ssh workflow-cps-global-lib workflow-multibranch pipeline-stage-tags-metadata pipeline-model-definition lockable-resources workflow-aggregator okhttp-api github-api git github github-branch-source pipeline-github-lib ssh-slaves matrix-auth jnr-posix-api pam-auth ldap email-ext config-file-provider nodejs javadoc maven-plugin run-condition conditional-buildstep envinject-api envinject parameterized-trigger windows-slaves external-monitor-job built-on-column jenkins-multijob-plugin jquery git-parameter"
  sudo java -jar ./jenkins-cli.jar -s "http://localhost:8080" -auth admin:$admin_pass install-plugin $plugins
  sudo service jenkins restart
  sudo usermod -a -G docker jenkins
  sudo usermod -a -G docker ec2-user
  sudo service docker start
  sudo chmod 666 /var/run/docker.sock
  # cd $workdir
  # sudo -H -u ec2-user bash -c 'admin_pass=`sudo cat /var/lib/jenkins/secrets/initialAdminPassword` && plugins=`cat ~/jenkins-config/plugins-list.txt` && java -jar ./jenkins-cli.jar -s "http://localhost:8080" -auth admin:$admin_pass install-plugin $plugins'
  EOT
}
