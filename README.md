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
* Alarm system (combined with Xiaomi and Owntracks)
* Interface in browser using websockets
* .. more to come


# How to
0) Install pre:
- jester
- multicast
- bcrypt
- websocket
- mqtt (not on nimble: https://github.com/barnybug/nim-mqtt)
- python (on your system)
- python pycrypto library (pip install pycrypto or how you like it: https://github.com/dlitz/pycrypto)
1) Clone the git
2) Copy secret_default.cfg to secret.cfg and fill in the data
3) Compile and run nimha.nim (`nim c -r nimha.nim`)
4) Access dashboard at 127.0.0.1:5000


# Current status
Very alpha. The next steps:

*At the very first a re-structure and naming of the files.*

0) Add nimble file and highlight requirements
1) Making it robust
2) More intuitive user input
3) Allow adjustment for disabling, e.g. Xiaomi without breaking the program
4) Add more features, e.g. Sony Songpal, Yeelight
5) Secure websocket - this has no restrictions
6) Secure WWW platform

# Screenshot
![Blog](private/screenshots/dashboard.png)