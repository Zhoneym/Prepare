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
cat << EOF | tee license.rb
require "openssl"
require "gitlab/license"
key_pair = OpenSSL::PKey::RSA.generate(2048)
File.open("license_key", "w") { |f| f.write(key_pair.to_pem) }
public_key = key_pair.public_key
File.open("license_key.pub", "w") { |f| f.write(public_key.to_pem) }
private_key = OpenSSL::PKey::RSA.new File.read("license_key")
Gitlab::License.encryption_key = private_key
license = Gitlab::License.new
license.licensee = {
"Name" => "Administrator",
"Company" => "none",
"Email" => "no-reply@gitlab.local",
}
license.starts_at = Date.new(2025, 1, 1)
license.expires_at = Date.new(2100, 1, 1)
license.notify_admins_at = Date.new(2099, 12, 1)
license.notify_users_at = Date.new(2099, 12, 1)
license.block_changes_at = Date.new(2100, 1, 1)
license.restrictions = {
active_user_count: 10000000,
}
puts "License:"
puts license
data = license.export
puts "Exported license:"
puts data
File.open("GitLabBV.gitlab-license", "w") { |f| f.write(data) }
public_key = OpenSSL::PKey::RSA.new File.read("license_key.pub")
Gitlab::License.encryption_key = public_key
data = File.read("GitLabBV.gitlab-license")
$license = Gitlab::License.import(data)
puts "Imported license:"
puts $license
unless $license
raise "The license is invalid."
end
if $license.restricted?(:active_user_count)
active_user_count = 10000000
if active_user_count > $license.restrictions[:active_user_count]
    raise "The active user count exceeds the allowed amount!"
end
end
if $license.notify_admins?
puts "The license is due to expire on #{$license.expires_at}."
end
if $license.notify_users?
puts "The license is due to expire on #{$license.expires_at}."
end
module Gitlab
class GitAccess
    def check(cmd, changes = nil)
    if $license.block_changes?
        return build_status_object(false, "License expired")
    end
    end
end
end
puts "This instance of GitLab Enterprise Edition is licensed to:"
$license.licensee.each do |key, value|
puts "#{key}: #{value}"
end
if $license.expired?
puts "The license expired on #{$license.expires_at}"
elsif $license.will_expire?
puts "The license will expire on #{$license.expires_at}"
else
puts "The license will never expire."
end
EOF
ruby license.rb
rm -rf /opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub
cp license_key.pub /opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub
sed -i 's/restricted_attr(:plan).presence || STARTER_PLAN/restricted_attr(:plan).presence || ULTIMATE_PLAN/' /opt/gitlab/embedded/service/gitlab-rails/ee/app/models/license.rb
gitlab-ctl kill && gitlab-ctl start
cat GitLabBV.gitlab-license
