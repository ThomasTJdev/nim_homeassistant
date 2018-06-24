# Copyright 2018 - Thomas T. Jarløv


import asyncdispatch
import osproc
import parsecfg
import strutils
import streams
import websocket

from os import sleep

import ../resources/alarm/alarm
import ../resources/mqtt/mqtt_func
import ../resources/os/os_utils
import ../resources/owntracks/owntracks
import ../resources/pushbullet/pushbullet
import ../resources/web/web_utils
import ../resources/xiaomi/xiaomi



var ws: AsyncWebSocket

var localhostKey = ""
  

proc setupWs() =
  ## Setup connection to WS

  echo "Mosquitto MAIN ws connection started"

  ws = waitFor newAsyncWebsocketClient("127.0.0.1", Port(25437), path = "/", protocols = @["nimha"])

  # Set WSS key for communication without verification on 127.0.0.1
  var dict = loadConfig("config/secret.cfg")
  localhostKey = dict.getSectionValue("Websocket", "wsLocalKey")


proc mosquittoParse(payload: string) {.async.} =
  ## Parse the raw output from Mosquitto sub

  let topicName = payload.split(" ")[0]
  let message   = payload.replace(topicName & " ", "")
  case topicName
  of "alarm":
    asyncCheck alarmParseMqtt(message)

  of "osstats":
    asyncCheck osParseMqtt(message)

  of "owntracks":
    asyncCheck owntracksParseMqtt(message)

  of "pushbullet":
    asyncCheck pushbulletParseMqtt(message)

  of "webutils":
    asyncCheck webParseMqtt(message)

  of "xiaomi":
    asyncCheck xiaomiParseMqtt(message) 

  of "wss/to":
    if isNil(ws):
      setupWs()

    if not isNil(ws):
      waitFor ws.sendText(localhostKey & message, false)
    else:
      echo "Gateway: Error, websocket not connected"

  of "history":
    # Add history to var and every nth update database with it.
    # SQLite can not cope with all the data, which results in
    # database is locked, and history elements are discarded
    discard

  else:
    discard



var mqttProcess: Process

proc mosquittoSub() =
  ## Start Mosquitto sub listening on #

  echo "Mosquitto MAIN sub started"

  mqttProcess = startProcess("/usr/bin/mosquitto_sub -v -t \"#\" -u " & s_MqttUsername & " -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort, options = {poEvalCommand})

  while running(mqttProcess):
    when defined(dev):
      let line = readLine(outputStream(mqttProcess))
      echo "MosSub: " & line & "\n"
      asyncCheck mosquittoParse(line)

    when not defined(dev):
      asyncCheck mosquittoParse(readLine(outputStream(mqttProcess)))



setupWs()
mosquittoSub()
quit()