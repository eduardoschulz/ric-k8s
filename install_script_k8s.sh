#!/bin/bash


#TODO check if root
#TODmO check if ubuntu 24.04LTS
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi


sudo apt update && sudo apt install curl conntrack socat
curl -LO https://dl.k8s.io/release/v1.30.2/bin/linux/amd64/kubectl
curl -LO https://dl.k8s.io/release/v1.30.2/bin/linux/amd64/kubectl.sha256
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
# TODO exit se check falhar
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
echo "Kubectl installed. Installing containerd"
sleep 2

#installing containerd
curl -LO https://github.com/containerd/containerd/releases/download/v1.7.16/containerd-1.7.16-linux-amd64.tar.gz && sudo tar Cxzvf /usr/local containerd-1.7.16-linux-amd64.tar.gz
curl -LO https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
sudo mv containerd.service /etc/systemd/system/containerd.service
sudo systemctl daemon-reload && sudo systemctl enable --now containerd
echo "Containerd installed. Installing runc"
sleep 2
#install runc
wget https://github.com/opencontainers/runc/releases/download/v1.1.13/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

echo "Runc installed. Installing cni plugins"
sleep 2
#install cni plugins 
#wget https://github.com/containernetworking/plugins/releases/download/v1.5.1/cni-plugins-linux-amd64-v1.5.1.tgz
#sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.5.1.tgz
sudo mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/v1.5.1/cni-plugins-linux-amd64-v1.5.1.tgz" | sudo tar -C /opt/cni/bin -xz

sudo -i
mkdir -p /etc/containerd/ && containerd config default | tee /etc/containerd/config.toml > /dev/null
systemctl daemon-reload && systemctl start containerd
echo "Cni plugins installed. Installing kubeadm and kubelet"
sleep 2
#installing kubeadm
#curl -L "https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz" | sudo tar -C /opt/cni/bin -xz
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz" | sudo tar -C /usr/local/bin -xz
sudo curl -L --remote-name-all https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/{kubeadm,kubelet}
sudo mv {kubeadm,kubelet} /usr/local/bin/
sudo chmod +x /usr/local/bin/{kubeadm,kubelet}


curl -sSL "https://raw.githubusercontent.com/kubernetes/release/v0.16.2/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:/usr/local/bin:g" | sudo tee /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/v0.16.2/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:/usr/local/bin:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

sudo systemctl daemon-reload && sudo systemctl enable --now kubelet
systemctl status kubelet.service | head
echo "Kubeadm and Kubelet installed. Setting up system..."
sleep 10

sudo su
swapoff -a
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
#setting up kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system


#sudo sed -i 's/\#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf #enable ipv4 forwarding
#sudo echo "1" > /proc/sys/net/ipv4/ip_forward #enable ipv4 forwarding
kubeadm init --config config.yaml
exit

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config



