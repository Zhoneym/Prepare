#!/bin/bash

sed -i 's|https://repo.openeuler.org|https://mirrors.tuna.tsinghua.edu.cn/openeuler|g' /etc/yum.repos.d/openEuler.repo
sed -i 's|gpgcheck=1|gpgcheck=0|g' /etc/yum.repos.d/openEuler.repo
sed -i '/^metalink=/d' /etc/yum.repos.d/openEuler.repo
sed -i '/^metadata_expire=/d' /etc/yum.repos.d/openEuler.repo
sed -i '/^gpgkey=/d' /etc/yum.repos.d/openEuler.repo
dnf update -y
dnf install vim git zsh sqlite wget lsof nano util-linux-user tar open-iscsi nfs-utils -y
systemctl enable --now iscsid
echo "Select the container runtime to install:"
echo "1) Docker with CRI-Dockerd"
echo "2) CRI-o"
echo "3) Containerd Version.1.7.27"
echo "4) Containerd Version.2.1.3"

read -p "Enter the number (1-4): " runtime

if [ "$runtime" == "1" ]; then
    dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    sed -i 's|https://download.docker.com|https://mirrors.aliyun.com/docker-ce|g' /etc/yum.repos.d/docker-ce.repo
    sed -i 's/\$releasever/10/g' /etc/yum.repos.d/docker-ce.repo
    dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin container-selinux -y
    systemctl enable --now docker.service docker.socket

    wget https://gh-proxy.com/https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.17/cri-dockerd-0.3.17.amd64.tgz
    tar xzvf cri-dockerd-0.3.17.amd64.tgz
    install -o root -g root -m 0755 cri-dockerd/cri-dockerd /usr/bin/cri-dockerd

    wget -O /etc/systemd/system/cri-docker.service https://gh-proxy.com/https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
    wget -O /etc/systemd/system/cri-docker.socket https://gh-proxy.com/https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket
    sed -i 's|^ExecStart=.*|ExecStart=/usr/bin/cri-dockerd --network-plugin=cni --pod-infra-container-image=registry.aliyuncs.com/google_containers/pause:3.10 --container-runtime-endpoint fd://|' /etc/systemd/system/cri-docker.service

    systemctl daemon-reload
    systemctl enable --now cri-docker.service cri-docker.socket

elif [ "$runtime" == "2" ]; then
    cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=cri-o
baseurl=https://mirrors.ustc.edu.cn/kubernetes/addons:/cri-o:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.ustc.edu.cn/kubernetes/addons:/cri-o:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF

    dnf install container-selinux cri-o -y

    cat <<EOF | tee /etc/crio/crio.conf
[crio]
selinux = false
umask = "0022"
[crio.runtime]
cgroup_manager = "systemd"
default_runtime = "runc"
[crio.runtime.runtimes.runc]
runtime_path = "/usr/bin/runc"
runtime_type = "oci"
runtime_root = "/run/runc"
[crio.image]
pause_image = "registry.aliyuncs.com/google_containers/pause:3.10"
[crio.network]
default_network = "cni"
network_dir = "/etc/cni/net.d/"
plugin_dirs = ["/opt/cni/bin/"]
EOF

    wget https://gh-proxy.com/https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
    install -m 755 runc.amd64 /usr/local/sbin/runc

    wget https://gh-proxy.com/https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
    mkdir -p /opt/cni/bin
    tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.7.1.tgz

    systemctl daemon-reload
    systemctl enable --now crio

elif [ "$runtime" == "3" ]; then
    dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    sed -i 's|https://download.docker.com|https://mirrors.aliyun.com/docker-ce|g' /etc/yum.repos.d/docker-ce.repo
    sed -i 's/\$releasever/10/g' /etc/yum.repos.d/docker-ce.repo
    dnf install containerd.io container-selinux -y

    containerd config default > /etc/containerd/config.toml
    sed -i 's|registry.k8s.io/pause:3.8|registry.aliyuncs.com/google_containers/pause:3.10|g' /etc/containerd/config.toml
    sed -i 's|SystemdCgroup = false|SystemdCgroup = true|g' /etc/containerd/config.toml

    wget https://gh-proxy.com/https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
    install -m 755 runc.amd64 /usr/local/sbin/runc

    wget https://gh-proxy.com/https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
    mkdir -p /opt/cni/bin
    tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.7.1.tgz

    systemctl daemon-reload
    systemctl enable --now containerd

elif [ "$runtime" == "4" ]; then
    dnf install container-selinux -y

    wget https://gh-proxy.com/https://github.com/containerd/containerd/releases/download/v2.1.3/containerd-2.1.3-linux-amd64.tar.gz
    tar Cxzvf /usr/local containerd-2.1.3-linux-amd64.tar.gz

    wget -O /etc/systemd/system/containerd.service https://gh-proxy.com/https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
    mkdir -p /etc/containerd/
    containerd config default > /etc/containerd/config.toml

    sed -i 's|registry.k8s.io|registry.aliyuncs.com/google_containers|g' /etc/containerd/config.toml
    sed -i "/enable_tls_streaming = false/a \    [plugins.'io.containerd.grpc.v1.cri'.containerd.runtimes.runc.options]\n      SystemdCgroup = true" /etc/containerd/config.toml

    wget https://gh-proxy.com/https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
    install -m 755 runc.amd64 /usr/local/sbin/runc

    wget https://gh-proxy.com/https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
    mkdir -p /opt/cni/bin
    tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.7.1.tgz

    systemctl daemon-reload
    systemctl enable --now containerd

else
    echo "Invalid input. Please choose a number between 1 and 4."
    exit 1
fi

setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
iptables -F && iptables-save
systemctl stop firewalld.service && systemctl disable firewalld.service
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=kubernetes
# baseurl=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.33/rpm/
enabled=1
gpgcheck=1
# gpgkey=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/repodata/repomd.xml.key
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.33/rpm/repodata/repomd.xml.key
EOF
dnf install kubelet kubeadm kubectl -y
cat>> /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1 
net.bridge.bridge-nf-call-iptables = 1 
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
vm.max_map_count=262144
EOF
modprobe br_netfilter
modprobe dm_crypt
sysctl -p /etc/sysctl.d/99-kubernetes.conf
dnf install ipvsadm -y
mkdir -p /etc/sysconfig/modules/
cat>> /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack"
for kernel_module in \${ipvs_modules}; do
/sbin/modinfo -F filename \${kernel_module} > /dev/null 2>&1
if [ $? -eq 0 ]; then
/sbin/modprobe \${kernel_module}
fi
done
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules
lsmod | grep ip_vs
mkdir /var/log/journal
mkdir /etc/systemd/journald.conf.d
cat >> /etc/systemd/journald.conf.d/99-prophet.conf <<EOF
[Journal]
Storage=persistent
Compress=yes
SyncIntervalSec=5m
RateLimitInterval=30s
RateLimitBurst=1000
SystemMaxUse=10G
SystemMaxFileSize=200M
MaxRetentionSec=6week
ForwardToSyslog=no
EOF
systemctl restart systemd-journald
chronyc -a makestep && date
sed -i '/^\[Service\]/a Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=systemd"' /usr/lib/systemd/system/kubelet.service
systemctl daemon-reload
systemctl enable --now kubelet.service

cat << EOF | tee /usr/local/bin/init-modules.sh
#!/bin/bash

modprobe br_netfilter
modprobe dm_crypt
sysctl -p /etc/sysctl.d/99-kubernetes.conf
bash /etc/sysconfig/modules/ipvs.modules
EOF
chmod a+x /usr/local/bin/init-modules.sh

cat << EOF | tee /etc/systemd/system/init-modules.service
[Unit]
Description=Load kernel modules and sysctl settings for Kubernetes
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/init-modules.sh
Restart=always
RestartSec=20s

[Install]
WantedBy=multi-user.target
EOF
systemctl enable init-modules.service

wget https://get.helm.sh/helm-v3.18.3-linux-amd64.tar.gz
tar -zxvf helm-v3.18.3-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm

HOST=$(hostname)
IP=$(hostname -I | awk '{print $1}')

if [ -n "$IP" ]; then
    FOUND_V4=$(grep -F "$IP" /etc/hosts)
    if [ -z "$FOUND_V4" ]; then
        echo "$IP    $HOST" >> /etc/hosts
        echo "Added IPv4: $IP    $HOST"
    else
        echo "IPv4 address already exists: $IP"
    fi
else
    echo "No IPv4 address found, skipping IPv4 hosts configuration. Please add manually."
fi
grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"
stat -fc %T /sys/fs/cgroup

echo -e "[Manager]\nDefaultLimitNOFILE=1073741816" > /etc/systemd/system.conf
echo -e "[Manager]\nDefaultLimitNOFILE=1073741816" > /etc/systemd/user.conf
