# Copyright 2018 - Thomas T. Jarløv

import osproc, os, sequtils

var runInLoop = true

var cron: Process
var wss: Process
var www: Process
var xiaomiListener: Process
var xiaomiRunner: Process
var main: Process
var alarm: Process
var owntracks: Process
var osstats: Process
var webutils: Process

proc handler() {.noconv.} =
  runInLoop = false
  kill(cron)
  kill(wss)
  kill(www)
  kill(xiaomiRunner)
  kill(xiaomiListener)
  kill(alarm)
  kill(owntracks)
  kill(osstats)
  kill(webutils)
  echo "Program quitted."
  quit()

setControlCHook(handler)



proc launcherActivated() =
  # 1) Executing the main-program in a loop.

  echo "Nim Home Assistant: Launcher initialized"
  wss = startProcess(getAppDir() & "/src/websocket/wss_runner", options = {poParentStreams})
  sleep(100)

  www = startProcess(getAppDir() & "/src/www/www_runner", options = {poParentStreams})
  sleep(100)

  cron = startProcess(getAppDir() & "/src/timing/cron_runner", options = {poParentStreams})
  sleep(100)

  alarm = startProcess(getAppDir() & "/src/alarm/alarm_runner", options = {poParentStreams})
  sleep(100)
  
  osstats = startProcess(getAppDir() & "/src/os/os_runner", options = {poParentStreams})
  sleep(100)

  webutils = startProcess(getAppDir() & "/src/web/web_runner", options = {poParentStreams})
  sleep(100)
  
  owntracks = startProcess(getAppDir() & "/src/owntracks/owntracks_runner", options = {poParentStreams})
  sleep(100)
  
  xiaomiRunner = startProcess(getAppDir() & "/src/xiaomi/xiaomi_runner", options = {poParentStreams})
  sleep(100)
  
  xiaomiListener = startProcess(getAppDir() & "/src/xiaomi/xiaomi_listener", options = {poParentStreams})
  echo "Starting monitor"

  while runInLoop:

    sleep(3000)

    if not running(owntracks):
      echo "owntracks_runner exited. Starting again.."
      owntracks = startProcess(getAppDir() & "/src/owntracks/owntracks_runner", options = {poParentStreams})

    if not running(wss):
      echo "wss_runner exited. Starting again.."
      wss = startProcess(getAppDir() & "/src/websocket/wss_runner", options = {poParentStreams})

    if not running(www):
      echo "www_runner exited. Starting again.."
      www = startProcess(getAppDir() & "/src/www/www_runner", options = {poParentStreams})

    if not running(xiaomiRunner):
      echo "xiaomi_runner exited. Starting again.."
      discard execCmd("pkill xiaomi_runner")
      kill(xiaomiListener)
      xiaomiRunner = startProcess(getAppDir() & "/src/xiaomi/xiaomi_runner", options = {poParentStreams})
    
    if not running(cron):
      echo "cron_runner exited. Starting again.."
      xiaomiRunner = startProcess(getAppDir() & "/src/timing/cron_runner", options = {poParentStreams})

    if not running(alarm):
      echo "alarm_runner exited. Starting again.."
      discard execCmd("pkill alarm_runner")
      xiaomiRunner = startProcess(getAppDir() & "/src/alarm/alarm_runner", options = {poParentStreams})

    if not running(osstats):
      echo "os_runner exited. Starting again.."
      osstats = startProcess(getAppDir() & "/src/os/os_runner", options = {poParentStreams})

    if not running(webutils):
      echo "web_runner exited. Starting again.."
      osstats = startProcess(getAppDir() & "/src/web/web_runner", options = {poParentStreams})

    if not running(xiaomiListener):
      echo "xiaomi_listener exited. Starting again.."
      xiaomiListener = startProcess(getAppDir() & "/src/xiaomi/xiaomi_listener", options = {poParentStreams})

  echo "Nim Home Assistant: Quitted"
  quit()




echo "Check if runners need compiling"
echo " .. please wait while compiling"

when defined(dev):
  let devC = " -d:dev "  
when not defined(dev):
  let devC = " "  


if not fileExists(getAppDir() & "/src/owntracks/owntracks_runner") or defined(rc) or defined(rcowntracks):
  let outputOwntrack = execCmd("nim c " & devC & getAppDir() & "/src/owntracks/owntracks_runner.nim")
  if outputOwntrack == 1:
    echo "\nAn error occured owntracks_runner\n\n"
    quit()
  else:
    echo "owntracks_runner compiling done\n\n"
    
if not fileExists(getAppDir() & "/src/websocket/wss_runner") or defined(rc) or defined(rcwss):    
  let outputWSS = execCmd("nim c -d:ssl " & devC & getAppDir() & "/src/websocket/wss_runner.nim")
  if outputWSS == 1:
    echo "\nAn error occured wss_runner\n\n"
    quit()
  else:
    echo "wss_runner compiling done\n\n"

if not fileExists(getAppDir() & "/src/timing/cron_runner") or defined(rc) or defined(rccron):
  let outputAlarm = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/src/timing/cron_runner.nim")
  if outputAlarm == 1:
    echo "\nAn error occured cron_runner\n\n"
    quit()
  else:
    echo "cron_runner compiling done\n\n"

if not fileExists(getAppDir() & "/src/alarm/alarm_runner") or defined(rc) or defined(rcalarm):
  let outputAlarm = execCmd("nim c -d:ssl -d:sqlsafe " & devC & getAppDir() & "/src/alarm/alarm_runner.nim")
  if outputAlarm == 1:
    echo "\nAn error occured alarm_runner\n\n"
    quit()
  else:
    echo "alarm_runner compiling done\n\n"

if not fileExists(getAppDir() & "/src/www/www_runner") or defined(rc) or defined(rcwww):
  let outputMain = execCmd("nim c -d:ssl -d:sqlsafe " & devC & getAppDir() & "/src/www/www_runner.nim")
  if outputMain == 1:
    echo "\nAn error occured www_runner\n\n"
    quit()
  else:
    echo "www_runner compiling done\n\n"

if not fileExists(getAppDir() & "/src/os/os_runner") or defined(rc) or defined(rcos):
  let outputOs = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/src/os/os_runner.nim")
  if outputOs == 1:
    echo "\nAn error occured os_runner\n\n"
    quit()
  else:
    echo "os_runner compiling done\n\n"

if not fileExists(getAppDir() & "/src/web/web_runner") or defined(rc) or defined(rcweb):
  let outputWebutils = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/src/web/web_runner.nim")
  if outputWebutils == 1:
    echo "\nAn error occured web_runner\n\n"
    quit()
  else:
    echo "web_runner compiling done\n\n"
  
if not fileExists(getAppDir() & "/src/xiaomi/xiaomi_listener") or defined(rc) or defined(rcxrunner):
  let outputXiaomiRunner = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/src/xiaomi/xiaomi_runner.nim")
  if outputXiaomiRunner == 1:
    echo "\nAn error occured xiaomi_runner\n\n"
    quit()
  else:
    echo "xiaomi_runner compiling done\n\n"

if not fileExists(getAppDir() & "/src/xiaomi/xiaomi_listener") or defined(rc) or defined(rcxlistener):
  let outputXiaomiListener = execCmd("nim c -d:sqlsafe " & devC & getAppDir() & "/src/xiaomi/xiaomi_listener.nim")
  if outputXiaomiListener == 1:
    echo "\nAn error occured nimha_xiaomi\n\n"
    quit()
  else:
    echo "outputXiaomiListener compiling done\n\n"


launcherActivated()