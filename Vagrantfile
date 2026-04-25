Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "devops-lab"

  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "devops-lab"
    vb.memory = 8192   # 8 GB RAM
    vb.cpus = 4        # 4 CPUs
  end

  config.vm.synced_folder ".", "/home/vagrant/project", type: "virtualbox"

  # -----------------------------
  # PROVISIONING SCRIPTS
  # -----------------------------
  
  config.vm.provision "shell", inline: <<-SHELL
  set -e

  echo "Giving execute permission to all scripts..."
  chmod +x /home/vagrant/project/scripts/*

  echo "Running Kubernetes install script..."
  bash /home/vagrant/project/scripts/kubernates.sh
  SHELL
  
  
  config.vm.provision "shell", inline: <<-SHELL
    set -e
    echo "Installing Docker..."
    bash /home/vagrant/project/scripts/docker.sh
  SHELL

  config.vm.provision "shell", inline: <<-SHELL
    set -e
    echo "Installing Kubernetes (k3s)..."
    bash /home/vagrant/project/scripts/kubernates.sh
  SHELL

  config.vm.provision "shell", inline: <<-SHELL
    set -e
    echo "Running base setup..."
    bash /home/vagrant/project/scripts/local-deploy.sh
  SHELL

end