# Nim Homeassistant

Nim Home Assistant is a hub for combining multiple home automation devices and automating jobs. Nim Home Assistant is developed to run on a Raspberry Pi with a 7" touchscreen, mobile devices and on large screens.


# Features
* MQTT
* Xiaomi Smart Home devices
* Certicate watch (SSL)
* Owntracks
* OS stats
* Pushbullet
* Mailing
* Cron jobs (timing)
* Alarm system (combined with Xiaomi and Owntracks)
* Interface in browser using websockets
* .. more to come


# How to

## Requirements

### Nim-lang
Nim-lang >= 0.18.1 (devel)
```
# Choosenim - https://github.com/dom96/choosenim
choosenim devel

# Or (e.g. for Raspberry pi)
# Follow https://github.com/nim-lang/Nim#compiling and
# then link your nim exec to the newly compiled nim
ln -sf /the/path/to/nim/git/Nim/bin/nim /usr/bin/nim
ln -sf /the/path/to/nim/git/Nim/bin/nimble /usr/bin/nimble
```

### Jester
Jester >= master

*Currently not available on nimble*

```
git clone https://github.com/dom96/jester.git
cd jester
nimble install
```

### Other prerequisite:
- multicast (nimble)
- bcrypt (nimble)
- websocket (nimble)
- openssl (on your system)
- python (on your system)
- pycrypto library (pip install pycrypto or how you like it: https://github.com/dlitz/pycrypto)
- Mosquitto MQTT (see section below for installing)
- Firewall - open ports: 443 (SSL) and 8883 (MQTT)




## Setup
**To access NimHA you need to use your local ip (e.g. 192.168.1.20) - it is not possible to access at 127.0.0.1.**

### Clone the git or use Nimble
**Clone:**
```
git clone https://github.com/ThomasTJdev/nim_homeassistant.git
cd nim_homeassistant

# Use -d:dev to get all output
nim c nimha.nim
```
**Nimble:**
```
nimble install nim_homeassistant (insert current version)
cd ~/.nimble/pkgs/nimha-0.1.0
```

### Update your secret file:
```
# Open the file and insert your data
nano config/secret.cfg
```


### Start your MQTT broker
See the section below for installing Mosquitto MQTT broker or just start your broker:
```
sudo systemctl start mosquitto
```

### Run and add an admin user
```
# Run and add an admin user (only 1 admin user is allowed)
./nimha newuser -u:username -p:password -e:my@email.com

# Just run
./nimha

# Access the interface at
<lanip>:5000
```



# Current status
**Beta**

To do (not chronological):

- When deleting action-templates from e.g. alarm, delete on cascade
- Add nimble file
- Add more features, e.g. Sony Songpal, Yeelight
- Add delete on cascade
- Google Maps API in secret.cfg or table?
- Make individual databases for each modules history. SQLite can not keep up with data which causes a locked database
- Add a history page
- Add example use cases



# Screenshot
![Blog](private/screenshots/dashboard.png)



# MQTT Broker

The whole setup depends on a MQTT broker, which connects all the different modules. The current setup requires Mosquitto.

## Installing and running Mosquitto MQTT broker

```
# Install using your package manager

# Raspberry Pi
sudo apt install mosquitto mosquitto-clients

# Arch
sudo pacman -S mosquitto
```
### Add password
```
cd /etc/mosquitto
sudo nano passwd
# Change to yours
username:pwd
remoteuser:remotepwd
# Close the file and run
sudo mosquitto_passwd -U passwd
```

### Config
```
sudo nano /etcc/mosquitto/mosquitto.conf
# and add
port 1883 localhost
listener 8883
password_file /etc/mosquitto/passwd   
allow_anonymous false
```
### Enable run on boot
```
sudo systemctl enable mosquitto
sudo systemctl daemon-reload
sudo systemctl start mosquitto
```
### Add new user
*-b seems not to work ?? using hack:*
```
sudo mosquitto_passwd -c tmppwdfile username
# enter passwd
# copy content of tmppwdfile
# insert into real passwd file
```


# Nginx

```
sudo nano /etc/nginx/sites-enabled/default
# Add the sections below

# After adding the sections
sudo nginx -t
# If it shows any error - fix them
sudo nginx -s reload
```

## WWW server

```nginx
server {
  listen 443 ssl;
  server_name <domain> www.<domain>;

  # These lines will be added by certbot. If not - add them manually after running certbot
  #ssl on;
  #ssl_certificate /etc/letsencrypt/live/<domain>/fullchain.pem;
  #ssl_certificate_key /etc/letsencrypt/live/<domain>/privkey.pem;

  location / {
    root   /home/pi/nim_homeassistant/public;

    if ($request_uri ~* ".(ico|css|js|gif|jpe?g|png|svg)$") {
      expires max;
      access_log off;
      add_header Pragma public;
      add_header Cache-Control "public";
    }

    server_tokens off;
    add_header X-Frame-Options SAMEORIGIN;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    proxy_pass http://127.0.0.1:5000;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

## Websocket

```nginx
upstream websocketproxy {
    server 127.0.0.1:25437;
}

server {
    listen 443 ssl;
    server_name <domain>;

    # These lines will be added by certbot. If not - add them manually after running certbot
    #ssl on;
    #ssl_certificate /etc/letsencrypt/live/<domain>/fullchain.pem;
    #ssl_certificate_key /etc/letsencrypt/live/<domain>/privkey.pem;

    location / {
        proxy_http_version 1.1;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://websocketproxy;
    }
}

```

## MQTT

**MISSING**: How to use nginx and SSL certificate with Mosquitto MQTT.

```nginx
#server {
#    listen 8883;
#    server_name <domain>;

#    location / {
#      proxy_pass http://127.0.0.1:8883;
#    }
#}

```




# SSl certificate

## Raspberry pi

### Add to sources
```
sudo nano /etc/apt/sources.list
```
### Append
```
deb http://ftp.debian.org/debian jessie-backports main
```
### Add keys
```
gpg --keyserver pgpkeys.mit.edu --recv-key  8B48AD6246925553
gpg -a --export 8B48AD6246925553 | sudo apt-key add -
gpg --keyserver pgpkeys.mit.edu --recv-key  7638D0442B90D010
gpg -a --export 7638D0442B90D010 | sudo apt-key add -
```
### Update source
```
sudo apt update
```
### Install
```
sudo apt-get install python-certbot-nginx -t jessie-backports
```
### Obtaining certificate
Due to the old version of cerbot, you have to mangle a little
```
sudo certbot --authenticator standalone --installer nginx -d <domain> --pre-hook "service nginx stop" --post-hook "service nginx start"
```

## Linux

Please use your package manager (install certbot-nginx) or visit https://certbot.eff.org/all-instructions for instructions.

### Install certificate

*Remember that your router must have port 80 open for the challenge*

```
sudo certbot --nginx -d domain.com -d www.domain.com
```

