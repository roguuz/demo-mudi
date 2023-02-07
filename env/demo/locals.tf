locals {
  name = "demo-mudi"
  jenkins_user_data = <<-EOT
  #!/bin/bash
  set -x
  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
  workdir="/home/ec2-user"
  cd $workdir
  sudo yum update -y
  sudo amazon-linux-extras install java-openjdk11 -y
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
  wget http://localhost:8080/jnlpJars/jenkins-cli.jar
  sudo sed -i "s|Environment.*=.*JAVA_OPTS.*\"|$(sudo grep 'Environment.*=.*JAVA_OPTS' /usr/lib/systemd/system/jenkins.service \
  sed 's|\"$||' sudo sed 's|$-Djenkins.install.runSetupWizard=false\"|')|g" /usr/lib/systemd/system/jenkins.service
  sed -i 's|<useSecurity>true</useSecurity>|<useSecurity>false</useSecurity>|g' /var/lib/jenkins/config.xml 
  plugins=$(cat $jenkins_configdir/plugins-list.txt)
  java -jar ./jenkins-cli.jar -s "http://localhost:8080" -auth admin:$admin_pass install-plugin $plugins
  sudo systemctl daemon-reload
  sudo service jenkins restart
  cd $workdir
  sudo -H -u ec2-user bash -c 'admin_pass=`sudo cat /var/lib/jenkins/secrets/initialAdminPassword` && plugins=`cat ~/jenkins-config/plugins-list.txt` && java -jar ./jenkins-cli.jar -s "http://localhost:8080" -auth admin:$admin_pass install-plugin $plugins'
  EOT
}