# Copyright 2018 - Thomas T. Jarløv


import asyncdispatch
import osproc
import parsecfg
import strutils
import streams
import websocket

from os import sleep, getAppDir

import ../resources/mqtt/mqtt_func
import ../resources/utils/log_utils


var ws: AsyncWebSocket

var localhostKey = ""


proc setupWs() =
  ## Setup connection to WS

  logit("WSgateway", "INFO", "Mosquitto Client Websocket connection started")

  ws = waitFor newAsyncWebsocketClient("127.0.0.1", Port(25437), path = "/", protocols = @["nimha"])

  # Set WSS key for communication without verification on 127.0.0.1
  var dict = loadConfig(replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/config/secret.cfg")
  localhostKey = dict.getSectionValue("Websocket", "wsLocalKey")


proc mosquittoParse(payload: string) {.async.} =
  ## Parse the raw output from Mosquitto sub

  let topicName = payload.split(" ")[0]
  let message   = payload.replace(topicName & " ", "")

  logit("WSgateway", "DEBUG", "Payload: " & message)

  if isNil(ws):
    setupWs()

  if not isNil(ws):
    waitFor ws.sendText(localhostKey & message)
  else:
    logit("WSgateway", "ERROR", "127.0.0.1 client websocket not connected")


var mqttProcess: Process

proc mosquittoSub() =
  ## Start Mosquitto sub listening on #

  logit("WSgateway", "INFO", "Mosquitto WS started")

  mqttProcess = startProcess(s_mqttPathSub & " -v -t \"wss/to\" -u nimhagate -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort, options = {poEvalCommand})

  while running(mqttProcess):
    asyncCheck mosquittoParse(readLine(outputStream(mqttProcess)))


setupWs()
mosquittoSub()
quit()