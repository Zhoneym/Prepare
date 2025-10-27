#!/bin/bash
sed -i 's|https://repo.openeuler.org|https://mirrors.ustc.edu.cn/openeuler|g' /etc/yum.repos.d/openEuler.repo
sed -i 's|gpgcheck=1|gpgcheck=0|g' /etc/yum.repos.d/openEuler.repo
sed -i '/^metalink=/d' /etc/yum.repos.d/openEuler.repo
sed -i '/^metadata_expire=/d' /etc/yum.repos.d/openEuler.repo
sed -i '/^gpgkey=/d' /etc/yum.repos.d/openEuler.repo
dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sed -i 's|https://download.docker.com|https://mirrors.aliyun.com/docker-ce|g' /etc/yum.repos.d/docker-ce.repo
sed -i 's/\$releasever/10/g' /etc/yum.repos.d/docker-ce.repo
dnf update -y
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin container-selinux -y
systemctl enable --now docker.service docker.socket
mkdir -p /app/onlyoffice
chmod 755 /app/onlyoffice
mkdir -p /app/onlyoffice/mysql/conf.d
mkdir -p /app/onlyoffice/mysql/data
mkdir -p /app/onlyoffice/mysql/initdb
mkdir -p /app/onlyoffice/CommunityServer/data
mkdir -p /app/onlyoffice/CommunityServer/logs
mkdir -p /app/onlyoffice/CommunityServer/letsencrypt
mkdir -p /app/onlyoffice/DocumentServer/Data
mkdir -p /app/onlyoffice/DocumentServer/App_Data
mkdir -p /app/onlyoffice/DocumentServer/sdkjs-plugins
mkdir -p /app/onlyoffice/DocumentServer/logs
mkdir -p /app/onlyoffice/MailServer/data/certs
mkdir -p /app/onlyoffice/MailServer/logs
mkdir -p /app/onlyoffice/ControlPanel/data
mkdir -p /app/onlyoffice/ControlPanel/logs
docker network create --driver bridge onlyoffice

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "$SERVER_IP mail.onlyoffice.local" | tee -a /etc/hosts
echo "$SERVER_IP onlyoffice.local" | tee -a /etc/hosts

cat /etc/hosts

echo "[mysqld]
sql_mode = 'NO_ENGINE_SUBSTITUTION'
max_connections = 1000
max_allowed_packet = 1048576000
group_concat_max_len = 2048" > /app/onlyoffice/mysql/conf.d/onlyoffice.cnf

echo "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'onlyoffice-password';
CREATE USER IF NOT EXISTS 'onlyoffice_user'@'%' IDENTIFIED WITH mysql_native_password BY 'onlyoffice-password-user';
CREATE USER IF NOT EXISTS 'mail_admin'@'%' IDENTIFIED WITH mysql_native_password BY 'onlyoffice-password-mail';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'onlyoffice_user'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'mail_admin'@'%';
FLUSH PRIVILEGES;" > /app/onlyoffice/mysql/initdb/setup.sql

docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-mysql-server \
    -v /app/onlyoffice/mysql/conf.d:/etc/mysql/conf.d -v /app/onlyoffice/mysql/data:/var/lib/mysql \
    -v /app/onlyoffice/mysql/initdb:/docker-entrypoint-initdb.d \
    -e MYSQL_ROOT_PASSWORD=onlyoffice-password -e MYSQL_DATABASE=onlyoffice docker.m.daocloud.io/library/mysql:8.0.29

docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-document-server \
    --privileged -e ALLOW_PRIVATE_IP_ADDRESS=true -e JWT_ENABLED=false \
    -v /app/onlyoffice/DocumentServer/logs:/var/log/onlyoffice \
    -v /app/onlyoffice/DocumentServer/Data:/var/www/onlyoffice/Data \
    -v /app/onlyoffice/DocumentServer/App_Data:/var/www/onlyoffice/App_Data \
    -v /app/onlyoffice/DocumentServer/sdkjs-plugins:/var/www/onlyoffice/documentserver/sdkjs-plugins \
    -v /proc/cpuinfo:/host/proc/cpuinfo -v /sys/class:/host/sys/class crpi-jfv3ro7j3i1a1bjk.cn-shanghai.personal.cr.aliyuncs.com/moqisoft/documentserver:9.1.0-amd64

docker run --init --net onlyoffice --privileged -i -t -d --restart=always --name onlyoffice-mail-server -p 25:25 -p 143:143 -p 587:587 \
    -e MYSQL_SERVER=onlyoffice-mysql-server \
    -e MYSQL_SERVER_PORT=3306 -e MYSQL_ROOT_USER=root \
    -e MYSQL_ROOT_PASSWD=onlyoffice-password \
    -e MYSQL_SERVER_DB_NAME=onlyoffice_mailserver \
    -v /app/onlyoffice/MailServer/data:/var/vmail \
    -v /app/onlyoffice/MailServer/data/certs:/etc/pki/tls/mailserver \
    -v /app/onlyoffice/MailServer/logs:/var/log \
    -h mail.onlyoffice.local docker.m.daocloud.io/onlyoffice/mailserver

docker run --net onlyoffice -i -t -d --restart=always --name onlyoffice-control-panel \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /app/onlyoffice/CommunityServer/data:/app/onlyoffice/CommunityServer/data \
    -v /app/onlyoffice/ControlPanel/data:/var/www/onlyoffice/Data \
    -v /app/onlyoffice/ControlPanel/logs:/var/log/onlyoffice docker.m.daocloud.io/onlyoffice/controlpanel

MAIL_SERVER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' onlyoffice-mail-server)

docker run --net onlyoffice -i -t -d --privileged --restart=always --name onlyoffice-community-server -p 8078:80 -p 8043:443 -p 5222:5222 --cgroupns=host \
    -e MYSQL_SERVER_ROOT_PASSWORD=onlyoffice-password \
    -e MYSQL_SERVER_DB_NAME=onlyoffice \
    -e MYSQL_SERVER_HOST=onlyoffice-mysql-server \
    -e MYSQL_SERVER_USER=onlyoffice_user \
    -e MYSQL_SERVER_PASS=onlyoffice-password-user \
    -e DOCUMENT_SERVER_PORT_80_TCP_ADDR=onlyoffice-document-server \
    -e MAIL_SERVER_API_HOST=172.18.0.3 \
    -e MAIL_SERVER_DB_HOST=onlyoffice-mysql-server \
    -e MAIL_SERVER_DB_NAME=onlyoffice_mailserver \
    -e MAIL_SERVER_DB_PORT=3306 -e MAIL_SERVER_DB_USER=root \
    -e MAIL_SERVER_DB_PASS=onlyoffice-password \
    -e CONTROL_PANEL_PORT_80_TCP=80 \
    -e CONTROL_PANEL_PORT_80_TCP_ADDR=onlyoffice-control-panel \
    -v /app/onlyoffice/CommunityServer/data:/var/www/onlyoffice/Data \
    -v /app/onlyoffice/CommunityServer/logs:/var/log/onlyoffice \
    -v /app/onlyoffice/CommunityServer/letsencrypt:/etc/letsencrypt \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw docker.m.daocloud.io/onlyoffice/communityserver
