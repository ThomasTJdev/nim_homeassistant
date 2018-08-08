# Copyright 2018 - Thomas T. Jarløv

import os
import osproc
import parsecfg
import re
import sequtils
import strutils

import nimhapkg/resources/users/user_add
import nimhapkg/resources/database/database

# Import procs to generate database tables
import nimhapkg/resources/database/modules/alarm_database
import nimhapkg/resources/database/modules/cron_database
import nimhapkg/resources/database/modules/mail_database
import nimhapkg/resources/database/modules/filestream_database
import nimhapkg/resources/database/modules/mqtt_database
import nimhapkg/resources/database/modules/owntracks_database
import nimhapkg/resources/database/modules/pushbullet_database
import nimhapkg/resources/database/modules/rss_database
import nimhapkg/resources/database/modules/xiaomi_database


var runInLoop = true

var cron: Process
var gateway: Process
var gatewayws: Process
var wss: Process
var www: Process
var xiaomiList: Process


let secretDir = getAppDir() & "/config/secret.cfg"
let dict = loadConfig(secretDir)


proc handler() {.noconv.} =
  runInLoop = false
  kill(cron)
  kill(gateway)
  kill(gatewayws)
  kill(wss)
  kill(www)
  kill(xiaomiList)
  echo "Program quitted."
  quit()

setControlCHook(handler)


proc secretCfg() =
  ## Check if secret.cfg exists

  if not fileExists(secretDir):
    copyFile(getAppDir() & "/config/secret_default.cfg", secretDir)
    echo "\nYour secret.cfg has been generated at " & secretDir & ". Please fill in your data\n"

proc updateJsFile() = 
  ## Updates the JS file with Websocket details from secret.cfg

  let wsAddressTo     = "var wsAddress   = \"" & dict.getSectionValue("Websocket","wsAddress") & "\""
  let wsProtocolTo    = "var wsProtocol  = \"" & dict.getSectionValue("Websocket","wsProtocol") & "\""
  let wsPortTo        = "var wsPort      = \"" & dict.getSectionValue("Websocket","wsPort") & "\""
  
  let wsAddressFrom   = "var wsAddress   = \"127.0.0.1\""
  let wsProtocolFrom  = "var wsProtocol  = \"ws\""
  let wsPortFrom      = "var wsPort      = \"25437\""
  
  for fn in [getAppDir() & "/public/js/js.js"]:
    fn.writeFile fn.readFile.replace(re("var wsAddress   = \".*\""), wsAddressTo)
    fn.writeFile fn.readFile.replace(re("var wsProtocol  = \".*\""), wsProtocolTo)
    fn.writeFile fn.readFile.replace(re("var wsPort      = \".*\""), wsPortTo)

  echo "Javascript: File updated with websocket connection details\n"


proc checkMosquittoBroker() =
  ## Check is the path to Mosquitto broker exists else quit

  var mosquitto: File
  if not mosquitto.open(dict.getSectionValue("MQTT", "mqttPathSub")):
    echo "\n\nMosquitto broker: Error in path. No file found at " & dict.getSectionValue("MQTT","mqttPathSub") & "\n"
    quit()

  if dict.getSectionValue("MQTT", "mqttIp") == "":
    echo "\n\nMosquitto broker: Missing connection details - You have not update secret.cfg with your details. Please insert your data in " & getAppDir() & "/config/secret_default.cfg to continue\n"
    quit()


proc createDbTables() =
  ## Create all tables
  ##
  ## To be macro based

  var db = conn()

  alarmDatabase(db)
  mailDatabase(db)
  owntracksDatabase(db)
  pushbulletDatabase(db)
  rssDatabase(db)
  xiaomiDatabase(db)
  cronDatabase(db)
  filestreamDatabase(db)
  mqttDatabase(db)


proc launcherActivated() =
  ## Executing the main-program in a loop.

  # Add an admin user
  if "newuser" in commandLineParams():
    createAdminUser(commandLineParams())

  echo "\nNim Home Assistant: Starting launcher"
  echo " .. please wait\n"

  wss     = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_websocket", options = {poParentStreams})
  # Gateway may first be started after wss
  sleep(2000)
  gateway = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_gateway", options = {poParentStreams})
  gatewayws = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_gateway_ws", options = {poParentStreams})
  www     = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_webinterface", options = {poParentStreams})
  cron    = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_cron", options = {poParentStreams})
  sleep(2000)
  xiaomiList  = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_xiaomilistener", options = {poParentStreams})
  sleep(1000)

  echo "\n .. waiting time over"
  echo "Nim Home Assistant: Launcher initialized\n"

  while runInLoop:

    sleep(3000)

    if not running(wss):
      echo "nimha_websocket exited. Killing gatewayWS and starting again.."
      kill(gatewayws)
      wss = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_websocket", options = {poParentStreams})
      sleep(1500)

    # Gateway may first be started, when wss is running.
    # Otherwise it will miss the connection and the local key exchange
    if not running(gatewayws) and running(wss):
      echo "gateway_ws exited. Starting again.."
      gateway = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_gateway_ws", options = {poParentStreams})

    if not running(gateway):
      echo "gateway exited. Starting again.."
      gateway = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_gateway", options = {poParentStreams})

    if not running(www):
      echo "nimha_webinterface exited. Starting again.."
      www = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_webinterface", options = {poParentStreams})

    if not running(cron):
      echo "nimha_cron exited. Starting again.."
      cron = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_cron", options = {poParentStreams})

    if not running(xiaomiList):
      echo "nimha_xiaomilistener exited. Starting again.."
      xiaomiList = startProcess(getAppDir() & "/nimhapkg/mainmodules/nimha_xiaomilistener", options = {poParentStreams})

  echo "Nim Home Assistant: Quitted"



proc compileIt() =
  echo "Checking if runners need compiling"
  echo " .. please wait\n"

  var devC = ""
  when defined(dev):
    devC.add(" -d:dev ")
  when defined(devmailon):
    devC.add(" -d:devmailon ")
  when defined(logoutput):
    devC.add(" -d:logoutput "  )

    
  # Websocket
  if not fileExists(getAppDir() & "/nimhapkg/mainmodules/nimha_websocket") or defined(rc) or defined(rcwss):    
    let outputWSS = execCmd("nim c -d:ssl " & devC & getAppDir() & "/nimhapkg/mainmodules/nimha_websocket.nim")
    if outputWSS == 1:
      echo "\nAn error occured nimha_websocket\n\n"
      quit()
    else:
      echo "nimha_websocket compiling done\n\n"


  # Cron jobs
  if not fileExists(getAppDir() & "/nimhapkg/mainmodules/nimha_cron") or defined(rc) or defined(rccron):
    let outputAlarm = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/nimhapkg/mainmodules/nimha_cron.nim")
    if outputAlarm == 1:
      echo "\nAn error occured nimha_cron\n\n"
      quit()
    else:
      echo "nimha_cron compiling done\n\n"


  # Webinterface
  if not fileExists(getAppDir() & "/nimhapkg/mainmodules/nimha_webinterface") or defined(rc) or defined(rcwebinterface):
    let outputWww = execCmd("nim c -d:ssl " & devC & getAppDir() & "/nimhapkg/mainmodules/nimha_webinterface.nim")
    if outputWww == 1:
      echo "\nAn error occured nimha_webinterface\n\n"
      quit()
    else:
      echo "nimha_webinterface compiling done\n\n"


  # Gateway websocket
  if not fileExists(getAppDir() & "/nimhapkg/mainmodules/nimha_gateway_ws") or defined(rc) or defined(rcgatewayws):
    let outputGateway = execCmd("nim c -d:ssl " & devC & getAppDir() & "/nimhapkg/mainmodules/nimha_gateway_ws.nim")
    if outputGateway == 1:
      echo "\nAn error occured nimha_gateway_ws\n\n"
      quit()
    else:
      echo "nimha_gateway_ws compiling done\n\n"


  # Gateway
  if not fileExists(getAppDir() & "/nimhapkg/mainmodules/nimha_gateway") or defined(rc) or defined(rcgateway):
    let outputGateway = execCmd("nim c -d:ssl " & devC & getAppDir() & "/nimhapkg/mainmodules/nimha_gateway.nim")
    if outputGateway == 1:
      echo "\nAn error occured nimha_gateway\n\n"
      quit()
    else:
      echo "nimha_gateway compiling done\n\n"


  # Xiaomi listener
  if not fileExists(getAppDir() & "/nimhapkg/mainmodules/nimha_xiaomilistener") or defined(rc) or defined(rcxlistener):
    let outputXiaomiListener = execCmd("nim c " & devC & getAppDir() & "/nimhapkg/mainmodules/nimha_xiaomilistener.nim")
    if outputXiaomiListener == 1:
      echo "\nAn error occured nimha_xiaomi\n\n"
      quit()
    else:
      echo "outputXiaomiListener compiling done\n\n"


proc requirements() =
  discard existsOrCreateDir("tmp")
  secretCfg()
  updateJsFile()
  checkMosquittoBroker()
  createDbTables()
  compileIt()
  launcherActivated()


requirements()