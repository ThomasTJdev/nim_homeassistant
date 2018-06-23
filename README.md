# Nim Homeassistant

Nim Home Assistant is a hub for combining multiple home automation devices and automating jobs. Nim Home Assistant is developed to run on a Raspberry Pi with a 7" touchscreen.


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

## Caution
 - Nim-lang >= 0.18.1 (devel) (check https://github.com/dom96/choosenim or on Raspberry Pi check the section below)
 - Jester >= master (it is not available at Nimble yet. Clone and nimble install.)

## Requirements
### Prerequisite:
- multicast (nimble)
- bcrypt (nimble)
- websocket (nimble)
- openssl (on your system)
- python (on your system)
- pycrypto library (pip install pycrypto or how you like it: https://github.com/dlitz/pycrypto)
- MQTT broker (see section below for Mosquitto)

**Jester:**
```
git clone https://github.com/dom96/jester.git
cd jester
nimble install
```
**Nim-lang:**
```
choosenim devel
```
OR

Follow https://github.com/nim-lang/Nim#compiling and then:
```
# Then link your nim exec to the newly compiled nim
ln -sf /usr/bin/nim /the/path/to/nim/git/Nim/bin/nim
ln -sf /usr/bin/nimble /the/path/to/nim/git/Nim/bin/nimble
```

## Setup
**It is currently not possible to run NimHA without a webserver. To access NimHA you need to use your local ip (e.g. 192.168.1.20) - 127.0.0.1/localhost is not working.**

### Clone the git (nimble is not ready yet)
```
git clone https://github.com/ThomasTJdev/nim_homeassistant.git
cd nim_homeassistant
```

### Update your secret file:
```
cp config/secret_default.cfg config/secret.cfg

# Open the file and insert your data
nano config/secret.cfg
```

### Adjust the websocket address in the JS file
```
nano public/js/.js.js

# Adjust
var wsAddress   = "127.0.0.1" // IP or url to websocket server
var wsProto     = "ws" // Use "wss" for SSL connection
```

### Compile and run:
```
# Use -d:dev to get all output
nim c nimha.nim

# From now on just run
./nimha
```


# Current status
Soon beta. The next steps (not chronological):

- Run NimHA locally with access on 127.0.0.1
- Add nimble file and highlight requirements
- Add more features, e.g. Sony Songpal, Yeelight
- When deleting templates, update templates users, e.g. alarm actions
- Google Maps API in secret.cfg or table?
- Make individual databases for each modules history. SQLite can not keep up with data which causes a locked database
- Add example use cases
- reCaptcha implementation



# Screenshot
![Blog](private/screenshots/dashboard.png)



# MQTT Broker

The whole setup depends on a MQTT broker, which connects all the different modules. You can use any broker. The following shows how to use Mosquitto.

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

*To do: SSL*
```nginx
server {
    listen 8883;
    server_name <domain>;

    location / {
      proxy_pass http://127.0.0.1:8883;
    }
}

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

