# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  # Box
  config.vm.box = "ubuntu/trusty64"

  # Box Configurations - more power!
  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--memory", 2048]
    v.customize ["modifyvm", :id, "--cpus", 2]
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  # SSH Agent Forwarding
  config.ssh.forward_agent = true

  # Hostnames
  config.vm.hostname = "nextcloud.example.org"

  # Private Network
  config.vm.network :private_network, ip: "192.168.50.12"

  # Provisioning
  config.vm.provision "provision", type: "shell", :path => "provision.sh", args: [
    "pass@word1", # MySQL password
    "nextcloud.example.org", # Server name
    "nextcloud@example.org", # Server admin
    "admin", # Admin username
    "pass@word1", # Admin password
  ]

  config.vm.provision "no-tty-fix", type: "shell", inline: "sed -i '/tty/!s/mesg n/tty -s \\&\\& mesg n/' /root/.profile"
end
