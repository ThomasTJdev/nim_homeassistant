# Copyright 2018 - Thomas T. Jarløv

import osproc, os, sequtils

var runInLoop = true

var cron: Process
var gateway: Process
var wss: Process
var www: Process
var xiaomiListener: Process


proc handler() {.noconv.} =
  runInLoop = false
  kill(cron)
  kill(gateway)
  kill(wss)
  kill(www)
  kill(xiaomiListener)
  echo "Program quitted."
  quit()

setControlCHook(handler)



proc launcherActivated() =
  ## Executing the main-program in a loop.

  echo "Nim Home Assistant: Launcher initializing"

  wss = startProcess(getAppDir() & "/src/mainmodules/nimha_websocket", options = {poParentStreams})
  
  # Gateway may first be started after wss
  gateway = startProcess(getAppDir() & "/src/mainmodules/nimha_gateway", options = {poParentStreams})

  www = startProcess(getAppDir() & "/src/mainmodules/nimha_webinterface", options = {poParentStreams})

  cron = startProcess(getAppDir() & "/src/mainmodules/nimha_cron", options = {poParentStreams})
  
  xiaomiListener = startProcess(getAppDir() & "/src/mainmodules/nimha_xiaomilistener", options = {poParentStreams})

  echo "Nim Home Assistant: Launcher initialized"

  while runInLoop:

    sleep(3000)

    if not running(wss):
      echo "nimha_websocket exited. Starting again.."
      wss = startProcess(getAppDir() & "/src/mainmodules/nimha_websocket", options = {poParentStreams})

    # Gateway may first be started, when wss is running.
    # Otherwise it will miss the connection
    if not running(gateway) and running(wss):
      echo "main exited. Starting again.."
      gateway = startProcess(getAppDir() & "/src/mainmodules/nimha_gateway", options = {poParentStreams})

    if not running(www):
      echo "nimha_webinterface exited. Starting again.."
      www = startProcess(getAppDir() & "/src/mainmodules/nimha_webinterface", options = {poParentStreams})

    if not running(cron):
      echo "nimha_cron exited. Starting again.."
      cron = startProcess(getAppDir() & "/src/mainmodules/nimha_cron", options = {poParentStreams})

    if not running(xiaomiListener):
      echo "nimha_xiaomilistener exited. Starting again.."
      xiaomiListener = startProcess(getAppDir() & "/src/mainmodules/nimha_xiaomilistener", options = {poParentStreams})

  echo "Nim Home Assistant: Quitted"




echo "Check if runners need compiling"
echo " .. please wait\n"

when defined(dev):
  let devC = " -d:dev "  
when not defined(dev):
  let devC = " "  


# Websocket
if not fileExists(getAppDir() & "/src/mainmodules/nimha_websocket") or defined(rc) or defined(rcwss):    
  let outputWSS = execCmd("nim c -d:ssl " & devC & getAppDir() & "/src/mainmodules/nimha_websocket.nim")
  if outputWSS == 1:
    echo "\nAn error occured nimha_websocket\n\n"
    quit()
  else:
    echo "nimha_websocket compiling done\n\n"


# Cron jobs
if not fileExists(getAppDir() & "/src/mainmodules/nimha_cron") or defined(rc) or defined(rccron):
  let outputAlarm = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/src/mainmodules/nimha_cron.nim")
  if outputAlarm == 1:
    echo "\nAn error occured nimha_cron\n\n"
    quit()
  else:
    echo "nimha_cron compiling done\n\n"


# Webinterface
if not fileExists(getAppDir() & "/src/mainmodules/nimha_webinterface") or defined(rc) or defined(rcwebinterface):
  let outputWww = execCmd("nim c -d:ssl -d:sqlsafe " & devC & getAppDir() & "/src/mainmodules/nimha_webinterface.nim")
  if outputWww == 1:
    echo "\nAn error occured nimha_webinterface\n\n"
    quit()
  else:
    echo "nimha_webinterface compiling done\n\n"


# Gateway
if not fileExists(getAppDir() & "/src/mainmodules/nimha_gateway") or defined(rc) or defined(rcgateway):
  let outputGateway = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/src/mainmodules/nimha_gateway.nim")
  if outputGateway == 1:
    echo "\nAn error occured nimha_gateway\n\n"
    quit()
  else:
    echo "nimha_gateway compiling done\n\n"


# Xiaomi listener
if not fileExists(getAppDir() & "/src/mainmodules/nimha_xiaomilistener") or defined(rc) or defined(rcxlistener):
  let outputXiaomiListener = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/src/mainmodules/nimha_xiaomilistener.nim")
  if outputXiaomiListener == 1:
    echo "\nAn error occured nimha_xiaomi\n\n"
    quit()
  else:
    echo "outputXiaomiListener compiling done\n\n"


launcherActivated()