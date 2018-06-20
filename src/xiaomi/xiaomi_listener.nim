# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import db_sqlite
import json
import mqtt
import net
import os
import multicast
#import ../database/database
#import ../database/sql_safe
import ../mqtt/mqtt_func


# Multicast parameters
const xiaomiMulticast = "224.0.0.50"
const xiaomiPort = 9898
const xiaomiMsgLen = 1024


# Vars used in socket
var xdata: string = ""
var xaddress: string = ""
var xport: Port


# Db connection
#var db = conn()


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
    echo "could not join multicast group"
    #exec(db, sql"INSERT INTO mainevents (event, value) VALUES (?, ?)", "error", "xiaomi", "Xiaomi listener could not join multicast group")
    quit()

  # Send connection confirmation
  discard mqttSend("xiaomilisten", "xiaomi/connect/listener", """{"cmd":"connect","model":"connect","sid":"connect","short_id":"connect","token":"connect","data":"{\"connect\":\"true\"}"}""")
  #execSafe(db, sql"INSERT INTO mainevents (event, value) VALUES (?, ?)", "listener", "xiaomi", "Xiaomi listener startet")

  #xsocket.enableBroadcast true

  #var gwExists = ""
  #var dbCheck = true
  while true:
    if xsocket.recvFrom(xdata, xiaomiMsgLen, xaddress, xport) > 0:
      #[
      # Get gateway sid
      if jn(parseJson(xdata), "cmd") == "heartbeat" and jn(parseJson(xdata), "token") != "":
        let sid = jn(parseJson(xdata), "sid")
        let token = jn(parseJson(xdata), "token")

        try:
          gwExists = getValueSafe(db, sql"SELECT sid FROM xiaomi_api WHERE sid = ?", sid)
          #if gwExists 
        except DbError:
          echo "Xiaomi error: DB locked"

        if gwExists == "":
          discard tryExec(db, sql"INSERT INTO xiaomi_devices (sid, name, model) VALUES (?, ?, ?)", sid, "Gateway", "gateway")
          discard tryExec(db, sql"INSERT INTO xiaomi_api (sid, token) VALUES (?, ?)", sid, token)

        else:
          discard tryExec(db, sql"UPDATE xiaomi_api SET token = ? WHERE sid = ?", jn(parseJson(xdata), "token"), sid)]#


      # Send data over MQTT
      discard mqttSend("xiaomilisten", "xiaomi", xdata)

  # Close group
  discard xsocket.leaveGroup(xgroup) == true


when isMainModule:
  sleep(1500) # Wait for other processes to start
  echo "Xiaomi multicast listener is started"
  xiaomiListen()
  #runForever()