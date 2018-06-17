# Package
version       = "0.1.0"
author        = "Thomas T. Jarløv (https://github.com/ThomasTJdev)"
description   = "Home assistant"
license       = "GPLv3"
bin           = @["homeassistant"]
skipDirs      = @["private"]
#skipExt       = @["nim"]



# Dependencies
requires "nim >= 0.18.0"
requires "jester >= 0.2.0"
requires "recaptcha >= 1.0.2"
requires "bcrypt >= 0.2.1"
requires "multicast >= 0.1.1"
requires "websocket >= 0.13.0" # Maybe ??
recaptcha

requires https://github.com/barnybug/nim-mqtt + paho-mqtt-c-git


import distros

task setup, "Generating executable":
  if detectOs(Windows):
    echo "Cannot run on Windows"
    quit()

  if not fileExists("config/config.cfg"):
    exec "cp config/secret_default.cfg config/secret.cfg"
  
  exec "nim c -d:release src/xiaomi/xiaomiListener.nim -o:src/xiaomi/xiaomiListener"

before install:
    setupTask()