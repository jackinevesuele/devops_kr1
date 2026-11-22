#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0
check() {
  if [[ "$2" == "$3" ]]; then echo "[OK] $1"; ((PASS++));
  else echo "[FAIL] $1: expected=$2 actual=$3"; ((FAIL++)); fi
}
echo "Audit: $(hostname -f)"
echo '[1] SSH'
cfg=$(sudo sshd -T)
check 'root login' no "$(awk '/^permitrootlogin/{print $2}' <<< "$cfg")"
check 'password authentication' no "$(awk '/^passwordauthentication/{print $2}' <<< "$cfg")"
check 'SSH port' 2222 "$(awk '/^port/{print $2}' <<< "$cfg")"
check 'MaxAuthTries' 3 "$(awk '/^maxauthtries/{print $2}' <<< "$cfg")"
echo '[2] Firewall'
check 'UFW active' active "$(sudo ufw status | awk '/^Status:/{print $2}')"
check 'incoming deny' yes "$(sudo ufw status verbose | grep -q 'deny (incoming)' && echo yes)"
echo '[3] Accounts'
id devops
if [[ -f /etc/nginx/sites-available/devops-site ]]; then
 echo '[4] Web server'
 check 'Nginx active' active "$(systemctl is-active nginx)"
 check 'TLS expires after 30 days' yes "$(openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend 2592000 >/dev/null && echo yes)"
 check 'key permissions' 600 "$(sudo stat -c %a /etc/ssl/private/devops.key)"
 check 'no world writable site files' 0 "$(find /var/www/devops-site -type f -perm -0002 | wc -l)"
fi
if command -v docker >/dev/null && [[ -f /home/devops/app/docker-compose.yml ]]; then
 echo '[5] Containers'
 check 'Docker active' active "$(systemctl is-active docker)"
 db=$(docker compose --project-directory /home/devops/app ps -q db)
 check 'PostgreSQL healthy' healthy "$(docker inspect -f '{{.State.Health.Status}}' "$db" 2>/dev/null)"
 check 'PR7 loopback' 127.0.0.1:5000 "$(docker compose --project-directory /home/devops/app port app 5000)"
 check 'PR7 env permissions' 600 "$(stat -c %a /home/devops/app/.env)"
fi
if [[ -f /home/devops/kr2/docker-compose.yml ]]; then
 echo '[6] KR2'
 cid=$(docker compose --project-directory /home/devops/kr2 ps -q redis)
 check 'Redis healthy' healthy "$(docker inspect -f '{{.State.Health.Status}}' "$cid" 2>/dev/null)"
 check 'KR2 loopback' 127.0.0.1:8002 "$(docker compose --project-directory /home/devops/kr2 port app 8002)"
 check 'KR2 env permissions' 600 "$(stat -c %a /home/devops/kr2/.env)"
 check 'KR2 TLS expires after 30 days' yes "$(openssl x509 -in /etc/ssl/certs/kr2.crt -noout -checkend 2592000 >/dev/null && echo yes)"
 check 'KR2 site enabled' yes "$(test -L /etc/nginx/sites-enabled/kr2 && echo yes)"
fi
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
