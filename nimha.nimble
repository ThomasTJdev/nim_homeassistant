# Package
version       = "0.4.5"
author        = "Thomas T. Jarløv (https://github.com/ThomasTJdev)"
description   = "Nim Home Assistant"
license       = "GPLv3"
bin           = @["nimha"]
skipDirs      = @["private"]
installDirs   = @["config", "public", "nimhapkg"]



# Dependencies
requires "nim >= 1.0.4"
requires "jester 0.4.3"
requires "httpbeast 0.2.2"
requires "recaptcha >= 1.0.2"
requires "bcrypt >= 0.2.1"
requires "multicast 0.1.4"
requires "websocket 0.4.1"
requires "wiringPiNim >= 0.1.0"
requires "xiaomi >= 0.1.4"


import distros

task setup, "Setup started":
  if detectOs(Windows):
    echo "Cannot run on Windows"
    quit()

before install:
  setupTask()

after install:
  echo "Development: Copy config/nimha_default.cfg to config/nimha_dev.cfg\n"
  echo "Production:  Copy config/nimha_default.cfg to /etc/nimha/nimha.cfg\n"