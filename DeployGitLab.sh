#!/bin/bash
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
iptables -F && iptables-save
systemctl stop firewalld.service && systemctl disable firewalld.service
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
echo -e "[Manager]\nDefaultLimitNOFILE=1073741816" > /etc/systemd/system.conf
echo -e "[Manager]\nDefaultLimitNOFILE=1073741816" > /etc/systemd/user.conf
curl "https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh" | bash
GITLAB_ROOT_EMAIL="no-reply@gitlab.local" EXTERNAL_URL="http://gitlab.local" dnf install gitlab-ee ruby -y
gem install gitlab-license
wget https://gh-proxy.com/https://ghproxy.gpnu.org/https://raw.githubusercontent.com/Zhoneym/PrepareKubernetes/refs/heads/main/License.rb
ruby License.rb
rm -rf /opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub
cp license_key.pub /opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub
sed -i 's/restricted_attr(:plan).presence || STARTER_PLAN/restricted_attr(:plan).presence || ULTIMATE_PLAN/' /opt/gitlab/embedded/service/gitlab-rails/ee/app/models/license.rb
gitlab-ctl kill && gitlab-ctl start
cat GitLabBV.gitlab-license
