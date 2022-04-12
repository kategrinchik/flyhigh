#!bin/bash
echo "Setting up timezone Europe/Moscow"
timedatectl set-timezone Europe/Moscow
echo "Setting up locale en_US.UTF-08"
locale-gen en_US.UTF-8
echo "Setting Port 2498 instead of 80 for sshd"
echo "Port 2498" >> /etc/ssh/sshd_config
echo "Restricting remote login for root"
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
systemctl restart sshd.service
echo "Adding user serviceuser"
adduser serviceuser
echo "Giving sudo privileges to user serviceuser"
usermod -aG sudo serviceuser
echo "Limit sudo privileges of user serviceuser to work only with systemd services"
deluser serviceuser sudo
echo "serviceuser ALL=(root) /bin/systemctl" | (EDITOR="tee -a" visudo -f /etc/sudoers.d/serviceuser)
apt update
echo "Installing nginx"
apt install nginx
systemctl enable nginx
echo "Installing monit"
apt install monit
systemctl enable monit
echo "Turning on basic authentification"
apt install openssl
printf "devops:$(openssl passwd -crypt test)\n" >> /etc/monit/.htpasswd
cat <<'EOF'>> /etc/monit/monitrc
set httpd port 2812 and
     use address localhost
     allow localhost
     allow crypt /etc/monit/.htpasswd devops
EOF
cat <<'EOF'>> /etc/monit/conf.d/nginx.conf
check process nginx with pidfile /run/nginx.pid
    start program = "/usr/sbin/service nginx start" with timeout 60 seconds
    stop program  = "/usr/sbin/service nginx stop"
    if failed host localhost port 80 protocol http for 3 cycles then restart
EOF
cat <<'EOF'>> /etc/nginx/conf.d/monit.conf
server {
    listen   80;
    server_name localhost;
    location /monit/ {
            rewrite ^/monit/(.*) /$1 break;
            proxy_ignore_client_abort on;
            proxy_pass http://localhost:2812;
            proxy_redirect http://localhost:2812 /monit;
            proxy_cookie_path / /monit/;
            proxy_set_header Host $host;
    }
}
EOF
systemctl reload nginx
systemctl reload monit
monit
echo "Monit is available on localhost/monit with devops:test"
echo "Settings the rules for ufw"
ufw enable
ufw allow 2498
ufw allow 80
ufw default deny incoming
ufw default allow outgoing
ufw reload
