# Copyright 2018 - Thomas T. Jarløv

# Copyright 2018 - Thomas T. Jarløv

import osproc, os, sequtils


var runInLoop = true


#var automation: Process
#var www: Process
var wss: Process
var xiaomiListener: Process
var xiaomiRunner: Process
var main: Process
var alarm: Process
var owntracks: Process
var osstats: Process
var webutils: Process

proc handler() {.noconv.} =
  ## Catch ctrl+c from user

  runInLoop = false
  #kill(automation)
  #kill(www)
  kill(wss)
  kill(main)
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
  # 2) Each time the main-program quits, there's a check
  # for a new version
  echo "Nim Home Assistant: Launcher initialized"
  #automation = startProcess(getAppDir() & "/nimha_auto", options = {poParentStreams})
  #www = startProcess(getAppDir() & "/nimha_main", options = {poParentStreams})
  wss = startProcess(getAppDir() & "/src/websocket/wss_runner", options = {poParentStreams})
  sleep(100)

  main = startProcess(getAppDir() & "/nimha_main", options = {poParentStreams})
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
    #if fileExists(getAppDir() & "/websitecreator_main_new"):
    #  moveFile(getAppDir() & "/websitecreator_main_new", getAppDir() & "/websitecreator_main")
    #[if not running(automation):
      www = startProcess(getAppDir() & "/nimha_auto")
      echo "nimha_auto exited. In 1.5 seconds, the program starts again."

      ]#

    sleep(3000)

    if not running(owntracks):
      owntracks = startProcess(getAppDir() & "/src/owntracks/owntracks_runner")
      echo "owntracks_runner exited. "

    if not running(wss):
      wss = startProcess(getAppDir() & "/src/websocket/wss_runner")
      echo "wss_runner exited."

    if not running(main):
      echo "nimha_main exited. "
      main = startProcess(getAppDir() & "/nimha_main", options = {poParentStreams})

    if not running(xiaomiRunner):
      echo "xiaomi_runner exited. "
      discard execCmd("pkill xiaomi_runner")
      kill(xiaomiListener)
      xiaomiRunner = startProcess(getAppDir() & "/src/xiaomi/xiaomi_runner", options = {poParentStreams})

    if not running(alarm):
      echo "alarm_runner exited. "
      discard execCmd("pkill alarm_runner")
      xiaomiRunner = startProcess(getAppDir() & "/src/alarm/alarm_runner", options = {poParentStreams})

    if not running(osstats):
      echo "os_runner exited. "
      osstats = startProcess(getAppDir() & "/src/os/os_runner", options = {poParentStreams})

    if not running(webutils):
      echo "web_runner exited. "
      osstats = startProcess(getAppDir() & "/src/web/web_runner", options = {poParentStreams})

    if not running(xiaomiListener):
      echo "xiaomi_listener exited. "
      xiaomiListener = startProcess(getAppDir() & "/src/xiaomi/xiaomi_listener", options = {poParentStreams})

    

  echo "Nim Home Assistant: Quitted"
  quit()


#if not fileExists(getAppDir() & "/nimha_auto") or not fileExists(getAppDir() & "/nimha_main") or not fileExists(getAppDir() & "/nimha_websocket") or 
if not fileExists(getAppDir() & "/src/xiaomi/xiaomi_listener") or not fileExists(getAppDir() & "/src/xiaomi/xiaomi_runner") or not fileExists(getAppDir() & "/src/websocket/wss_runner") or not fileExists(getAppDir() & "/src/web/web_runner") or not fileExists(getAppDir() & "/src/os/os_runner") or not fileExists(getAppDir() & "/src/owntracks/owntracks_runner") or not fileExists(getAppDir() & "/src/alarm/alarm_runner") or not fileExists(getAppDir() & "/nimha_main") or defined(rc):

  echo "Compiling"
  #echo " - Using params:" & addArgs()
  echo " - Using compile options in *.nim.cfg"
  echo " "
  echo " .. please wait while compiling"
  

  let outputOwntrack = execCmd("nim c " & getAppDir() & "/src/owntracks/owntracks_runner.nim")
  if outputOwntrack == 1:
    echo "\nAn error occured owntracks_runner"
    quit()
  else:
    echo "\n"
    echo "owntracks_runner compiling done."
    
    
  let outputWSS = execCmd("nim c -d:ssl " & getAppDir() & "/src/websocket/wss_runner.nim")
  if outputWSS == 1:
    echo "\nAn error occured wss_runner"
    quit()
  else:
    echo "\n"
    echo "wss_runner compiling done."
  

  let outputAlarm = execCmd("nim c -d:ssl -d:sqlsafe -d:dev " & getAppDir() & "/src/alarm/alarm_runner.nim")
  if outputAlarm == 1:
    echo "\nAn error occured alarm_runner"
    quit()
  else:
    echo "alarm_runner compiling done\n\n"


  let outputMain = execCmd("nim c -d:ssl -d:sqlsafe -d:dev " & getAppDir() & "/nimha_main.nim")
  if outputMain == 1:
    echo "\nAn error occured nimha_main"
    quit()
  else:
    echo "nimha_main compiling done\n\n"


  let outputOs = execCmd("nim c -d:sqlsafe -d:dev " & getAppDir() & "/src/os/os_runner.nim")
  if outputOs == 1:
    echo "\nAn error occured os_runner"
    quit()
  else:
    echo "os_runner compiling done\n\n"

  
  let outputWebutils = execCmd("nim c -d:sqlsafe -d:dev " & getAppDir() & "/src/web/web_runner.nim")
  if outputWebutils == 1:
    echo "\nAn error occured web_runner"
    quit()
  else:
    echo "web_runner compiling done\n\n"
  
  let outputXiaomiRunner = execCmd("nim c -d:sqlsafe -d:dev " & getAppDir() & "/src/xiaomi/xiaomi_runner.nim")
  if outputXiaomiRunner == 1:
    echo "\nAn error occured xiaomi_runner"
    quit()
  else:
    echo "\n"
    echo "xiaomi_runner compiling done."


  let outputXiaomiListener = execCmd("nim c -d:sqlsafe -d:dev " & getAppDir() & "/src/xiaomi/xiaomi_listener.nim")
  if outputXiaomiListener == 1:
    echo "\nAn error occured nimha_xiaomi"
    quit()
  else:
    echo "\n"

    echo """outputXiaomiListener compiling done. 
    
    """


else:
  launcherActivated()