# Package
version       = "0.1.0"
author        = "Thomas T. Jarløv (https://github.com/ThomasTJdev)"
description   = "Nim Home Assistant"
license       = "GPLv3"
bin           = @["nimha"]
skipDirs      = @["private"]



# Dependencies
requires "nim >= 0.18.1"
requires "jester >= 0.2.0" # master - git clone it
requires "recaptcha >= 1.0.2"
requires "bcrypt >= 0.2.1"
requires "multicast >= 0.1.1"
requires "websocket >= 0.3.1"


import distros

task setup, "Setup started":
  if detectOs(Windows):
    echo "Cannot run on Windows"
    quit()

  echo "\nJester: Please ensure that jester is installed from GIT\n"
  
before install:
    setupTask()