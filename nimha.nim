# Copyright 2018 - Thomas T. Jarløv

import os
import osproc
import parsecfg
import sequtils
import strutils

import src/resources/users/user_add

var runInLoop = true

var cron: Process
var gateway: Process
var wss: Process
var www: Process
var xiaomi: Process


let dict = loadConfig("config/secret.cfg")


proc handler() {.noconv.} =
  runInLoop = false
  kill(cron)
  kill(gateway)
  kill(wss)
  kill(www)
  kill(xiaomi)
  echo "Program quitted."
  quit()

setControlCHook(handler)


proc updateJsFile() = 
  ## Updates the JS file with Websocket details from secret.cfg

  let wsAddressTo     = "var wsAddress   = \"" & dict.getSectionValue("Websocket","wsAddress") & "\""
  let wsProtocolTo    = "var wsProtocol  = \"" & dict.getSectionValue("Websocket","wsProtocol") & "\""
  let wsPortTo        = "var wsPort      = \"" & dict.getSectionValue("Websocket","wsPort") & "\""
  
  let wsAddressFrom   = "var wsAddress   = \"127.0.0.1\""
  let wsProtocolFrom  = "var wsProtocol  = \"ws\""
  let wsPortFrom      = "var wsPort      = \"25437\""
  
  for fn in ["public/js/js.js"]:
    fn.writeFile fn.readFile.replace(wsAddressFrom, wsAddressTo)
    fn.writeFile fn.readFile.replace(wsProtocolFrom, wsProtocolTo)
    fn.writeFile fn.readFile.replace(wsPortFrom, wsPortTo)

  echo "Javascript: File updated with websocket connection details\n"


proc checkMosquittoBroker() =
  ## Check is the path to Mosquitto broker exists else quit

  var mosquitto: File
  if not mosquitto.open(dict.getSectionValue("MQTT","mqttPath")):
    echo "Mosquitto broker: Error in path. No file found at " & dict.getSectionValue("MQTT","mqttPath") & "\n"
    quit()


proc launcherActivated() =
  ## Executing the main-program in a loop.

  # Add an admin user
  if "newuser" in commandLineParams():
    createAdminUser(commandLineParams())

  updateJsFile()
  checkMosquittoBroker()

  echo "Nim Home Assistant: Starting launcher"

  wss     = startProcess(getAppDir() & "/src/mainmodules/nimha_websocket", options = {poParentStreams})
  # Gateway may first be started after wss
  gateway = startProcess(getAppDir() & "/src/mainmodules/nimha_gateway", options = {poParentStreams})
  www     = startProcess(getAppDir() & "/src/mainmodules/nimha_webinterface", options = {poParentStreams})
  cron    = startProcess(getAppDir() & "/src/mainmodules/nimha_cron", options = {poParentStreams})
  xiaomi  = startProcess(getAppDir() & "/src/mainmodules/nimha_xiaomilistener", options = {poParentStreams})

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

    if not running(xiaomi):
      echo "nimha_xiaomilistener exited. Starting again.."
      xiaomi = startProcess(getAppDir() & "/src/mainmodules/nimha_xiaomilistener", options = {poParentStreams})

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