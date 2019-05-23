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

let modulesDir =
  when defined(dev) or not defined(systemInstall):
    getAppDir() / "nimhapkg/mainmodules/"
  else:
    #installpath
    "/var/lib/nimha/mainmodules"

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

  when defined(dev) or not defined(systemInstall):
    let secretFn = getAppDir() / "config/nimha_dev.cfg"
    if not fileExists(secretFn):
      copyFile(getAppDir() / "config/nimha_default.cfg", secretFn)
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

  #installpath
  const persistent_dir = "/var/lib/nimha"
  let fn =
    when defined(dev) or not defined(systemInstall):
      getAppDir() / "public/js/script.js"
    else:
      persistent_dir / "public/js/script.js"

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

proc compileModule(devC, modulename: string) =
  ## Compile a module using Nim
  echo "compiling " & modulename
  let nimblepath = getNimbleCache() / "pkgs"
  let fn = modulesDir / modulename & ".nim"
  if not fileExists(fn):
    echo "ERROR: " & fn & " not found"
    quit(1)
  let cmd = "nim c --NimblePath:" & nimblepath & " -d:ssl " & devC & " " & fn
  echo "running " & cmd
  if execCmd(cmd) == 0:
    echo modulename & " compiling done"
  else:
    echo "An error has occurred compiling " & modulename
    # TODO: handle broken modules
    quit(1)


proc compileIt() =
  echo "Checking if runners in $# need compiling" % modulesDir

  var devC = ""
  when defined(dev):
    devC.add(" -d:dev ")
  when defined(devmailon):
    devC.add(" -d:devmailon ")
  when defined(logoutput):
    devC.add(" -d:logoutput "  )

  when not defined(dev) and defined(systemInstall):
    block:
      #installpath
      echo "Setting up Nimble and required dependencies"
      let cmd = "nimble install -y --verbose websocket bcrypt multicast nimcrypto xiaomi jester recaptcha --nimbleDir:" & getNimbleCache()
      echo cmd
      if execCmd(cmd) != 0:
        echo "Error running nimble"
        quit(1)

  # Websocket
  if not fileExists(modulesDir / "nimha_websocket") or defined(rc) or defined(rcwss):
    compileModule(devC, "nimha_websocket")

  # Cron jobs
  if not fileExists(modulesDir / "nimha_cron") or defined(rc) or defined(rccron):
    compileModule(devC, "nimha_cron")

  # Webinterface
  if not fileExists(modulesDir / "nimha_webinterface") or defined(rc) or defined(rcwebinterface):
    compileModule(devC, "nimha_webinterface")

  # Gateway websocket
  if not fileExists(modulesDir / "nimha_gateway_ws") or defined(rc) or defined(rcgatewayws):
    compileModule(devC, "nimha_gateway_ws")

  # Gateway
  if not fileExists(modulesDir / "nimha_gateway") or defined(rc) or defined(rcgateway):
    compileModule(devC, "nimha_gateway")

  # Xiaomi listener
  if not fileExists(modulesDir / "nimha_xiaomilistener") or defined(rc) or defined(rcxlistener):
    compileModule(devC, "nimha_xiaomilistener")


proc requirements() =
  when defined(dev) or not defined(systemInstall):
    discard existsOrCreateDir(getTmpDir())
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
