# Copyright 2018 - Thomas T. Jarløv


import asyncdispatch
import osproc
import parsecfg
import strutils
import streams
import websocket

from os import sleep, getAppDir

import ../resources/mqtt/mqtt_func



var ws: AsyncWebSocket

var localhostKey = ""
  

proc setupWs() =
  ## Setup connection to WS

  echo "Mosquitto Client Websocket connection started"

  ws = waitFor newAsyncWebsocketClient("127.0.0.1", Port(25437), path = "/", protocols = @["nimha"])

  # Set WSS key for communication without verification on 127.0.0.1
  var dict = loadConfig(replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/config/secret.cfg")
  localhostKey = dict.getSectionValue("Websocket", "wsLocalKey")


proc mosquittoParse(payload: string) {.async.} =
  ## Parse the raw output from Mosquitto sub

  let topicName = payload.split(" ")[0]
  let message   = payload.replace(topicName & " ", "")
  
  if topicName == "wss/to":
    when defined(dev):
      echo "MosWS: " & message & "\n"
  
    if isNil(ws):
      setupWs()

    if not isNil(ws):
      waitFor ws.sendText(localhostKey & message, false)
    else:
      echo "Mosquitto WS: Error, client websocket not connected"

  elif topicName == "history":
    # Add history to var and every nth update database with it.
    # SQLite can not cope with all the data, which results in
    # database is locked, and history elements are discarded
    discard

  else:
    discard



var mqttProcess: Process

proc mosquittoSub() =
  ## Start Mosquitto sub listening on #

  echo "Mosquitto WS started"

  mqttProcess = startProcess("/usr/bin/mosquitto_sub -v -t \"#\" -u " & s_MqttUsername & " -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort, options = {poEvalCommand})

  while running(mqttProcess):
    asyncCheck mosquittoParse(readLine(outputStream(mqttProcess)))


setupWs()
mosquittoSub()
quit()