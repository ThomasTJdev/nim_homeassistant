# Nim Homeassistant

Home Assistant in [Nim](https://nim-lang.org/)


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

***In the current beta nim version 0.18.0 and 0.18.1 is required!***

***The wss_runner.nim needs version 0.18.1, you need to manually change that in nimha.nim***

0) Install pre:
- jester (nimble)
- multicast (nimble)
- bcrypt (nimble)
- websocket (nimble)
- mqtt (not on nimble: https://github.com/barnybug/nim-mqtt)
- openssl
- paho library (MQTT) (For Rapsberry Pi, see at the bottom)
- python (on your system)
- pycrypto library (pip install pycrypto or how you like it: https://github.com/dlitz/pycrypto)
- MQTT broker (see section below)

1) Clone the git
2) Copy secret_default.cfg to secret.cfg and fill in the data
3) Compile and run nimha.nim (`nim c -r nimha.nim`)
4) Change the websocket IP in js.js, unless you use 127.0.0.1
5) Access dashboard at 127.0.0.1:5000 (if you are using nginx, use your local ip)


# Current status
Soon beta. The next steps (not chronological):

0) Add nimble file and highlight requirements
1) Making it robust - the websocket is unstable
2) More intuitive user input
3) Add more features, e.g. Sony Songpal, Yeelight
4) When deleting templates, update templates users, e.g. alarm actions
5) Google Maps API
6) Add example usecases
7) reCaptcha implementation


# Screenshot
![Blog](private/screenshots/dashboard.png)

# MQTT Broker

The whole setup depends on a MQTT broker, which connects all the different modules. You can use any broker. The following shows how to use Mosquitto.

## Installing and running Mosquitto MQTT broker

```
sudo apt install mosquitto mosquitto-clients
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

# Raspberry pi

The main purpose for Nim Home Assistant was to be light enough to run on small devices, e.g. a Raspberry Pi with a touchscreen.

## Paho for Raspberry Pi:
```bash
sudo apt-get install cmake make gcc libssl-dev
mkdir ~/home/pi/git && cd ~/git
git clone https://github.com/eclipse/paho.mqtt.c.git
cd paho.mqtt.c
make
sudo make install
sudo ldconfig
```

## Nginx

```
sudo nano /etc/nginx/sites-enabled/default
# Add the sections below

# After adding the sections
sudo nginx -t
# If it shows any error - fix them
sudo nginx -s reload
```

### WWW server

```nginx
server {
  listen 443 ssl;
  server_name <domain> www.<domain>;

  ssl on;
  ssl_certificate /etc/letsencrypt/live/<domain>/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/<domain>/privkey.pem;

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

### Websocket

```nginx
upstream websocketproxy {
    server 127.0.0.1:25437;
}

server {
    listen 443 ssl;
    server_name <domain>;

    ssl on;
    ssl_certificate /etc/letsencrypt/live/<domain>/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/<domain>/privkey.pem;

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

### MQTT

*Todo: SSL*
```nginx
server {
    listen 8883;
    server_name <domain>;

    location / {
      proxy_pass http://127.0.0.1:8883;
    }
}

```


## SSl certificate

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

## GCC 8

```
git clone https://bitbucket.org/sol_prog/raspberry-pi-gcc-binary.git
cd raspberry-pi-gcc-binary
tar xf gcc-8.1.0.tar.bz2
sudo mv gcc-8.1.0 /usr/local

# Temporarily change path
export PATH=/usr/local/gcc-8.1.0/bin:$PATH

# Make link static
echo 'export PATH=/usr/local/gcc-8.1.0/bin:$PATH' >> .bashrc
source .bashrc

# Check version
gcc-8.1.0 --version

# Symlink
# *Original gcc-4.9 is placed in /usr/bin/gcc-4.9*
sudo ln -sf /usr/local/gcc-8.1.0/bin/gcc-8.1.0 /usr/bin/gcc


# Optional: Cleanup - if you need the space
cd ..
cd rm -r raspberry-pi-gcc-binary

# Troubleshooting

## Xiaomi

Not getting any data from gateway: Check your firewall