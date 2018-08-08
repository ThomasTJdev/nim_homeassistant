# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import osproc
import parsecfg
import strutils
import streams

from os import sleep, getAppDir

import ../resources/alarm/alarm
import ../resources/mqtt/mqtt_func
import ../resources/os/os_utils
import ../resources/owntracks/owntracks
import ../resources/pushbullet/pushbullet
import ../resources/rss/rss_reader
import ../resources/web/web_utils
import ../resources/xiaomi/xiaomi_utils
import ../resources/utils/logging


proc mosquittoParse(payload: string) {.async.} =
  ## Parse the raw output from Mosquitto sub

  let topicName = payload.split(" ")[0]
  let message   = payload.replace(topicName & " ", "")
  
  if topicName notin ["xiaomi"]:
    logit("gateway", "DEBUG", "Topic: " & topicName & " - Payload: " & message)
  
  if topicName == "alarm":
    asyncCheck alarmParseMqtt(message)

  elif topicName == "osstats":
    asyncCheck osParseMqtt(message)

  elif topicName == "rss":
    asyncCheck rssParseMqtt(message)

  elif topicName == "pushbullet":
    asyncCheck pushbulletParseMqtt(message)

  elif topicName == "webutils":
    asyncCheck webParseMqtt(message)

  elif topicName == "xiaomi":
    asyncCheck xiaomiParseMqtt(message, alarmStatus) 

  elif topicName.substr(0, 8) == "owntracks":
    asyncCheck owntracksParseMqtt(message, topicName)

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

  logit("gateway", "INFO", "Mosquitto GATEWAY started")

  mqttProcess = startProcess(s_mqttPathSub & " -v -t \"#\" -u nimhawss -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort, options = {poEvalCommand})

  while running(mqttProcess):
    asyncCheck mosquittoParse(readLine(outputStream(mqttProcess)))


mosquittoSub()
quit()