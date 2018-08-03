# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import db_sqlite
import json
import net
import os
import multicast

import ../resources/mqtt/mqtt_func
import ../resources/utils/logging


# Multicast parameters
const xiaomiMulticast = "224.0.0.50"
const xiaomiPort = 9898
const xiaomiMsgLen = 1024


# Vars used in socket
var xdata: string = ""
var xaddress: string = ""
var xport: Port



template jn(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON

  try:
    json[data].getStr()
  except:
    ""


proc xiaomiListen() =
  ## Listen for Xiaomi

  let xgroup = xiaomiMulticast
  let xbindport = Port(xiaomiPort)
  let xsocket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  xsocket.setSockOpt(OptReuseAddr, true)
  xsocket.bindAddr(xbindport)

  if not xsocket.joinGroup(xgroup):
    logit("xiaomi", "ERROR", "Xiaomi: Could not join multicast group")
    quit()

  # Send connection confirmation
  mqttSend("xiaomilisten", "xiaomi/connect/listener", """{"cmd":"connect","model":"connect","sid":"connect","short_id":"connect","token":"connect","data":"{\"connect\":\"true\"}"}""")

  while true:
    if xsocket.recvFrom(xdata, xiaomiMsgLen, xaddress, xport) > 0:

      # Send data over MQTT
      mqttSend("xiaomilisten", "xiaomi", xdata)
      #logit("xiaomi", "DEBUG", xdata)

  # Close group
  discard xsocket.leaveGroup(xgroup) == true


when isMainModule:
  logit("xiaomi", "INFO", "Xiaomi multicast listener is started")
  xiaomiListen()