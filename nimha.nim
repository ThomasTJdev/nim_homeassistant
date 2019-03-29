# Copyright 2018 - Thomas T. Jarløv

import os
import osproc
import parsecfg
import re
import sequtils
import strutils
import tables

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

const moduleNames = ["websocket", "gateway_ws", "gateway", "webinterface", "cron",
  "xiaomilistener"]

var runInLoop = true

var modules = initTable[string, Process]()

var modulesDir = getAppDir() / "nimhapkg/mainmodules/"
let dict = loadConf("")


proc stop_and_quit() {.noconv.} =
  runInLoop = false
  for name, p in modules.pairs:
    echo "Stopping " & name
    kill(p)
  echo "Program quitted."
  quit()

setControlCHook(stop_and_quit)


proc secretCfg() =
  ## Check if config file exists

  when defined(dev):
    let secretFn = getAppDir() / "config/nimha_dev.cfg"
    if not fileExists(secretFn):
      copyFile(getAppDir() & "/config/nimha_default.cfg", secretFn)
      echo "\nThe config file has been generated at " & secretFn & ". Please fill in your data\n"
  else:
    if not fileExists("/etc/nimha/nimha.cfg"):
      echo "\nConfig file /etc/nimha/nimha.cfg does not exists\n"
      quit(0)

proc updateJsFile() =
  ## Updates the JS file with Websocket details from the config file

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


proc spawnModule(name: string) =
  let fn = modulesDir / "nimha_" & name
  let default_sandbox_cmd = dict.getSectionValue("Home", "default_sandbox")
  if default_sandbox_cmd == "":
    echo "Warning: running modules without sandbox"
  let cmdline =
    if default_sandbox_cmd == "":
      fn
    else:
      default_sandbox_cmd & " " & fn
  let exe = cmdline.splitWhitespace()[0]
  let args = cmdline.splitWhitespace()[1..^1]
  echo "Spawning " & name & " as " & cmdline
  let p = startProcess(exe, args=args, options = {poParentStreams})
  modules[name] = p

proc launcherActivated() =
  ## Executing the main-program in a loop.

  # Add an admin user
  if "newuser" in commandLineParams():
    createAdminUser(commandLineParams())

  echo "\nNim Home Assistant: Starting launcher"
  echo " .. please wait\n"

  for name in moduleNames:
    spawnModule(name)
    sleep(2000)

  echo "\n .. waiting time over"
  echo "Nim Home Assistant: Launcher initialized\n"

  while runInLoop:

    sleep(3000)

    for name, p in modules.pairs:
      if not running(p):
        echo name & " exited."
        if name == "websocket":
          kill(modules["gateway_ws"])
        spawnModule(name)
        sleep(2000)

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
      echo "\nAn error occurred nimha_websocket\n\n"
      quit()
    else:
      echo "nimha_websocket compiling done\n\n"


  # Cron jobs
  if not fileExists(modulesDir / "nimha_cron") or defined(rc) or defined(rccron):
    let outputAlarm = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_cron.nim")
    if outputAlarm == 1:
      echo "\nAn error occurred nimha_cron\n\n"
      quit()
    else:
      echo "nimha_cron compiling done\n\n"


  # Webinterface
  if not fileExists(modulesDir / "nimha_webinterface") or defined(rc) or defined(rcwebinterface):
    let outputWww = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_webinterface.nim")
    if outputWww == 1:
      echo "\nAn error occurred nimha_webinterface\n\n"
      quit()
    else:
      echo "nimha_webinterface compiling done\n\n"


  # Gateway websocket
  if not fileExists(modulesDir / "nimha_gateway_ws") or defined(rc) or defined(rcgatewayws):
    let outputGateway = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_gateway_ws.nim")
    if outputGateway == 1:
      echo "\nAn error occurred nimha_gateway_ws\n\n"
      quit()
    else:
      echo "nimha_gateway_ws compiling done\n\n"


  # Gateway
  if not fileExists(modulesDir / "nimha_gateway") or defined(rc) or defined(rcgateway):
    let outputGateway = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_gateway.nim")
    if outputGateway == 1:
      echo "\nAn error occurred nimha_gateway\n\n"
      quit()
    else:
      echo "nimha_gateway compiling done\n\n"


  # Xiaomi listener
  if not fileExists(modulesDir / "nimha_xiaomilistener") or defined(rc) or defined(rcxlistener):
    let outputXiaomiListener = execCmd("nim c -d:ssl " & devC & modulesDir / "nimha_xiaomilistener.nim")
    if outputXiaomiListener == 1:
      echo "\nAn error occurred nimha_xiaomi\n\n"
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
