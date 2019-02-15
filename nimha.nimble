# Package
version       = "0.4.1"
author        = "Thomas T. Jarløv (https://github.com/ThomasTJdev)"
description   = "Nim Home Assistant"
license       = "GPLv3"
bin           = @["nimha"]
skipDirs      = @["private"]
installDirs   = @["config", "public", "nimhapkg"]



# Dependencies
requires "nim >= 0.19.0"
requires "jester 0.4.1"
requires "httpbeast 0.2.1"
requires "recaptcha >= 1.0.2"
requires "bcrypt >= 0.2.1"
requires "multicast 0.1.4"
requires "websocket 0.3.5"
requires "wiringPiNim >= 0.1.0"
requires "xiaomi >= 0.1.3"


import distros

task setup, "Setup started":
  if detectOs(Windows):
    echo "Cannot run on Windows"
    quit()

before install:
  setupTask()

after install:
  echo "secret.cfg: Please update secret.cfg with your details. The file is located in the nimble package directory at config/secret.cfg\n"