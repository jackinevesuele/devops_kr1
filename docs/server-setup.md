# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
Ubuntu Server 24.04.5 LTS, VirtualBox, диск VDI 25 ГБ, 4096 МБ памяти, 1 виртуальный процессор. Одно ядро выбрано после зависания загрузки в режиме Hyper-V/NEM. Рабочие снимки создаются после штатного выключения, поскольку сохранение памяти работающей VM в данной среде вызывает ошибку VirtualBox.

## 2. Сетевые интерфейсы
enp0s3: NAT, 10.0.2.15/24, исходящий доступ. enp0s8: Host-only, 192.168.96.101/24, доступ с Windows. IPv6 link-local назначается автоматически. Фактические адреса проверять командой ip -br address.

## 3. Правило проброса портов
Имя ssh, TCP, адрес хоста 127.0.0.1, порт хоста 2222, порт гостя 2222. SSH-псевдоним Windows: Host devops, HostName 127.0.0.1, Port 2222, User devops, IdentityFile ~/.ssh/devops_vm, IdentitiesOnly yes. Ключ создан для этого стенда, закрытая часть остаётся на хосте.

## 4. Учётные записи
devops, UID 1001, группы sudo и docker; вход только по выделенному ключу Ed25519. ~/.ssh: 700; authorized_keys: 600; владелец devops. Исходная учётная запись student для SSH запрещена директивой AllowUsers.

## 5. Служба SSH
Основной /etc/ssh/sshd_config сохранён. /etc/ssh/sshd_config.d/99-hardening.conf: Port 2222, PermitRootLogin no, PasswordAuthentication no, PubkeyAuthentication yes, PermitEmptyPasswords no, MaxAuthTries 3, LoginGraceTime 30, AllowUsers devops, X11Forwarding no, ClientAliveInterval 300, ClientAliveCountMax 2. ssh.socket отключён; ssh.service включён. Перед применением: sudo sshd -t; проверить sudo sshd -T; затем перезапустить SSH, не закрывая рабочую сессию, и проверить новый вход.

## 6. Правила межсетевого экрана
UFW active; deny incoming, allow outgoing. TCP 2222 LIMIT, 80 ALLOW, 443 ALLOW, включая IPv6. Logging medium. Правила для 5000, 5432, 6379 и 8002 не добавляются. Установка Docker может менять отображаемую политику routed; исходное состояние КР2 фиксируется после ПР7. /etc/hosts Windows: 192.168.96.101 devops.local notes.devops.local.

## 7. Снимки состояния
01-clean-install — установка; 02-keys-configured — ключ; 03-ssh-hardened — SSH; 04-nginx-https — Nginx и TLS; 05-docker-compose — ПР7; 06-before-kr2 — до развёртывания КР2; 07-kr2 — итог. Не восстанавливать 01 на основном стенде без резервного снимка текущего результата. Для восстановления с 01 создать devops, установить ключ, записать SSH drop-in, отключить socket activation, изменить NAT guest port на 2222, затем последовательно задать UFW allow/limit и включить UFW. Проверять новый вход до закрытия старого.

## 8. Веб-сервер
Пакет nginx из Ubuntu. Конфигурация /etc/nginx/sites-available/devops-site, ссылка sites-enabled/devops-site; default отключён. Ресурс /var/www/devops-site, владелец devops, каталоги 755, файлы 644. TLS: /etc/ssl/certs/devops.crt 644 root, /etc/ssl/private/devops.key 600 root. Создание: sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'. HTTP перенаправляется на HTTPS; try_files и собственная 404; журналы /var/log/nginx/devops-site.access.log и .error.log. Применение: sudo nginx -t && sudo systemctl reload nginx. Публичный сертификат копируется на хост; закрытый ключ не копируется. deploy.sh выполняет rsync, проверку чистоты Git и HTTPS с доверенным сертификатом.
