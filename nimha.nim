# Copyright 2018 - Thomas T. Jarløv

import os
import osproc
import parsecfg
import re
import sequtils
import strutils

import nimhapkg/resources/utils/common
import nimhapkg/resources/users/user_add
import nimhapkg/resources/database/database

# Import procs to generate database tables
import nimhapkg/resources/database/modules/alarm_database
import nimhapkg/resources/database/modules/cron_database
import nimhapkg/resources/database/modules/mail_database
import nimhapkg/resources/database/modules/filestream_database
import nimhapkg/resources/database/modules/mqtt_database
import nimhapkg/resources/database/modules/os_database
import nimhapkg/resources/database/modules/owntracks_database
import nimhapkg/resources/database/modules/pushbullet_database
import nimhapkg/resources/database/modules/rpi_database
import nimhapkg/resources/database/modules/rss_database
import nimhapkg/resources/database/modules/xiaomi_database
import nimhapkg/modules/web/web_certs


var runInLoop = true

var cron: Process
var gateway: Process
var gatewayws: Process
var wss: Process
var www: Process
var xiaomiList: Process

var modulesDir = getAppDir() / "nimhapkg/mainmodules/"
let dict = loadConf("")


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

  let secretFn = getAppDir() / "config/secret.cfg"
  if not fileExists(secretFn):
    copyFile(getAppDir() & "/config/secret_default.cfg", secretFn)
    echo "\nYour secret.cfg has been generated at " & secretFn & ". Please fill in your data\n"

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

  var dbAlarm = conn("dbAlarm.db")
  var dbCron = conn("dbCron.db")
  var dbFile = conn("dbFile.db")
  var dbMail = conn("dbMail.db")
  var dbMqtt = conn("dbMqtt.db")
  var dbOs = conn("dbOs.db")
  var dbOwntracks = conn("dbOwntracks.db")
  var dbPushbullet = conn("dbPushbullet.db")
  var dbRpi = conn("dbRpi.db")
  var dbRss = conn("dbRss.db")
  var dbXiaomi = conn("dbXiaomi.db")
  var dbWeb = conn("dbWeb.db")

  alarmDatabase(dbAlarm)
  mailDatabase(dbMail)
  osDatabase(dbOs)
  owntracksDatabase(dbOwntracks)
  pushbulletDatabase(dbPushbullet)
  rssDatabase(dbRss)
  xiaomiDatabase(dbXiaomi)
  cronDatabase(dbCron)
  filestreamDatabase(dbFile)
  mqttDatabase(dbMqtt)
  rpiDatabase(dbRpi)
  certDatabase(dbWeb)


proc launcherActivated() =
  ## Executing the main-program in a loop.

  # Add an admin user
  if "newuser" in commandLineParams():
    createAdminUser(commandLineParams())

  echo "\nNim Home Assistant: Starting launcher"
  echo " .. please wait\n"

  wss     = startProcess(modulesDir / "nimha_websocket", options = {poParentStreams})
  # Gateway may first be started after wss
  sleep(2000)
  gatewayws = startProcess(modulesDir / "nimha_gateway_ws", options = {poParentStreams})
  sleep(1500)
  gateway = startProcess(modulesDir / "nimha_gateway", options = {poParentStreams})
  sleep(500)
  www     = startProcess(modulesDir / "nimha_webinterface", options = {poParentStreams})
  cron    = startProcess(modulesDir / "nimha_cron", options = {poParentStreams})
  sleep(2000)
  xiaomiList  = startProcess(modulesDir / "nimha_xiaomilistener", options = {poParentStreams})
  sleep(1000)

  echo "\n .. waiting time over"
  echo "Nim Home Assistant: Launcher initialized\n"

  while runInLoop:

    sleep(3000)

    if not running(wss):
      echo "nimha_websocket exited. Killing gatewayWS and starting again.."
      kill(gatewayws)
      wss = startProcess(modulesDir / "nimha_websocket", options = {poParentStreams})
      sleep(2000)

    # Gateway may first be started, when wss is running.
    # Otherwise it will miss the connection and the local key exchange
    if not running(gatewayws) and running(wss):
      echo "gateway_ws exited. Starting again.."
      gateway = startProcess(modulesDir / "nimha_gateway_ws", options = {poParentStreams})

    if not running(gateway):
      echo "gateway exited. Starting again.."
      gateway = startProcess(modulesDir / "nimha_gateway", options = {poParentStreams})

    if not running(www):
      echo "nimha_webinterface exited. Starting again.."
      www = startProcess(modulesDir / "nimha_webinterface", options = {poParentStreams})

    if not running(cron):
      echo "nimha_cron exited. Starting again.."
      cron = startProcess(modulesDir / "nimha_cron", options = {poParentStreams})

    if not running(xiaomiList):
      echo "nimha_xiaomilistener exited. Starting again.."
      xiaomiList = startProcess(modulesDir / "nimha_xiaomilistener", options = {poParentStreams})

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
  if not fileExists(modulesDir / "nimha_websocket") or defined(rc) or defined(rcwss):
    let outputWSS = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_websocket.nim")
    if outputWSS == 1:
      echo "\nAn error occured nimha_websocket\n\n"
      quit()
    else:
      echo "nimha_websocket compiling done\n\n"


  # Cron jobs
  if not fileExists(modulesDir / "nimha_cron") or defined(rc) or defined(rccron):
    let outputAlarm = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_cron.nim")
    if outputAlarm == 1:
      echo "\nAn error occured nimha_cron\n\n"
      quit()
    else:
      echo "nimha_cron compiling done\n\n"


  # Webinterface
  if not fileExists(modulesDir / "nimha_webinterface") or defined(rc) or defined(rcwebinterface):
    let outputWww = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_webinterface.nim")
    if outputWww == 1:
      echo "\nAn error occured nimha_webinterface\n\n"
      quit()
    else:
      echo "nimha_webinterface compiling done\n\n"


  # Gateway websocket
  if not fileExists(modulesDir / "nimha_gateway_ws") or defined(rc) or defined(rcgatewayws):
    let outputGateway = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_gateway_ws.nim")
    if outputGateway == 1:
      echo "\nAn error occured nimha_gateway_ws\n\n"
      quit()
    else:
      echo "nimha_gateway_ws compiling done\n\n"


  # Gateway
  if not fileExists(modulesDir / "nimha_gateway") or defined(rc) or defined(rcgateway):
    let outputGateway = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_gateway.nim")
    if outputGateway == 1:
      echo "\nAn error occured nimha_gateway\n\n"
      quit()
    else:
      echo "nimha_gateway compiling done\n\n"


  # Xiaomi listener
  if not fileExists(modulesDir / "nimha_xiaomilistener") or defined(rc) or defined(rcxlistener):
    let outputXiaomiListener = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_xiaomilistener.nim")
    if outputXiaomiListener == 1:
      echo "\nAn error occured nimha_xiaomi\n\n"
      quit()
    else:
      echo "outputXiaomiListener compiling done\n\n"


proc requirements() =
  discard existsOrCreateDir(replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/tmp")
  when defined(dev):
    secretCfg()
  updateJsFile()
  checkMosquittoBroker()
  createDbTables()
  compileIt()
  launcherActivated()

proc main() =
  requirements()

when isMainModule:
  main()
