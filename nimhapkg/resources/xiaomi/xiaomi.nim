# Copyright 2018 - Thomas T. Jarløv

import json, sequtils, strutils, net, sets, asyncdispatch, db_sqlite, osproc
import multicast

from os import getappdir

import ../database/database
import ../database/sql_safe
import ../utils/parsers

import ../mqtt/mqtt_func


type
  ## Connection to the Gateway
  Connection* = object of RootObj
    group*: string
    port*: Port
    command*: string
    socket*: Socket

  ## Gateway information
  Gateway* = object of RootObj # todo multiple gateways: ref object of Gateway
    cmd*: string
    model*: string
    sid*: string
    short_id*: string
    token*: string
    data*: string

  ## Response after a command is send
  Response* = object
    cmd*: string  
    model*: string
    sid*: string
    short_id*: string
    token*: string
    data*: string


## Multicast parameters
const xiaomiMulticast = "224.0.0.50"
const xiaomiPort = Port(9898)
const xiaomiMsgLen = 1024
var   xiaomiSocket: Socket
var   xiaomiGatewaySid = ""

#[# Xiaomi devices
const sensors = @["sensor_ht", "gateway"]
const binary_sensors = @["magnet", "motion", "switch", "86sw1", "86sw2", "cube", "smoke", "natgas"]
const switches = @["plug", "ctrl_neutral1", "ctrl_neutral2", "86plug"]
const lights = @["gateway"]]#


## Vars used in socket
var xdata: string = ""
var xaddress: string = ""
var xport: Port


## Db connection
var db = conn()


template jn(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON

  try:
    json[data].getStr()
  except:
    ""



proc xiaomiSoundPlay*(db: DbConn, ringtone = "8", volume = "4") =
  let gwData = getRow(db, sql"SELECT sid, token, key FROM xiaomi_api")

  if gwData[0] != "" and gwData[1] != "":

    let key = execProcess("python3 " & replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/nimhapkg/resources/xiaomi/xiaomi_key.py " & gwData[2] & " " & gwData[1])
    discard xiaomiSocket.sendTo(xiaomiMulticast, xiaomiPort, "{\"cmd\": \"write\", \"sid\": \"7811dcb8d102\", \"data\": { \"key\": \"" & replace(key, "\n", "") & "\", \"mid\": " & ringtone & ", \"vol\": " & volume & "} }")


proc xiaomiSoundStop*(db: DbConn) =
  let gwData = getRow(db, sql"SELECT sid, token, key FROM xiaomi_api")

  if gwData[0] != "" and gwData[1] != "":

    let key = execProcess("python3 " & replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/nimhapkg/resources/xiaomi/xiaomi_key.py " & gwData[2] & " " & gwData[1])
    discard xiaomiSocket.sendTo(xiaomiMulticast, xiaomiPort, "{\"cmd\": \"write\", \"sid\": \"7811dcb8d102\", \"data\": {\"key\": \"" & replace(key, "\n", "") & "\", \"mid\": 10000} }")
    

proc xiaomiGatewayLight*(db: DbConn, color = "0") =
  let gwData = getRow(db, sql"SELECT sid, token, key FROM xiaomi_api")

  if gwData[0] != "" and gwData[1] != "":
    var key = ""
    key = execProcess("python3 " & replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/nimhapkg/resources/xiaomi/xiaomi_key.py " & gwData[2] & " " & gwData[1])

    discard xiaomiSocket.sendTo(xiaomiMulticast, xiaomiPort, "{\"cmd\": \"write\", \"sid\": \"7811dcb8d102\", \"data\": {\"key\": \"" & replace(key, "\n", "") & "\", \"rgb\": " & color & "} }")
    


proc xiaomiWriteTemplate*(db: DbConn, id: string) {.async.} =
  ## Write a template to the gateway

  let data = getRowSafe(db, sql"SELECT sid, value_name, value_data FROM xiaomi_templates WHERE id = ?", id)

  if data[0] == "" or data[1] == "":
    return

  case data[1]
  of "ringtone":
    if data[2] == "10000":
      xiaomiSoundStop(db)
    
    elif data[2] != "":
      xiaomiSoundPlay(db, data[2])

    else:
      xiaomiSoundPlay(db)

  of "rgb":
    if data[2] != "":
      xiaomiGatewayLight(db, data[2])

    else:
      xiaomiGatewayLight(db)

  else:
    return


proc xiaomiSendReadCmd*(deviceSid, value: string) =
  ## Get data from a Xiaomi device

  let command = "{\"cmd\":\"read\", \"sid\":\"" & deviceSid & "\"}"
  discard xiaomiSocket.sendTo(xiaomiMulticast, xiaomiPort, command)



proc xiaomiReadDevice*(deviceSid: string) =
  ## Get data from a Xiaomi device

  let command = "{\"cmd\":\"read\", \"sid\":\"" & deviceSid & "\"}"
  discard xiaomiSocket.sendTo(xiaomiMulticast, xiaomiPort, command)
  while xiaomiSocket.recvFrom(xdata, xiaomiMsgLen, xaddress, xport) > 0:
    if jn(parseJson(xdata), "cmd") == "read_ack" and jn(parseJson(xdata), "sid") == deviceSid:
      
      when defined(dev):
        echo "DEV: " & xdata
      
      mqttSend("xiaomi", "xiaomi/read_ack", xdata)
      break


proc xiaomiDiscover*(db: DbConn, refreshDB = false) =
  ## Discover xiaomi devices

  when defined(dev):
    echo "DEV: Discovery started"

  if refreshDB:
    exec(db, sql"DELETE FROM xiaomi_devices")

  let command = "{\"cmd\":\"get_id_list\"}"
  discard xiaomiSocket.sendTo(xiaomiMulticast, xiaomiPort, command)
  var sids = ""
  while xiaomiSocket.recvFrom(xdata, xiaomiMsgLen, xaddress, xport) > 0:
    if jn(parseJson(xdata), "cmd") != "get_id_list_ack":
      continue

    sids = jn(parseJson(xdata), "data")

    when defined(dev):
      echo "DEV: sids: " & sids

    break
  
  var xiaomi_device = ""
  for sid in split(multiReplace(sids, [("[", ""), ("]", ""), ("\"", "")]), ","):
    when defined(dev):
      echo "DEV: read: " & sid

    let command = "{\"cmd\":\"read\", \"sid\":\"" & sid & "\"}"
    discard xiaomiSocket.sendTo(xiaomiMulticast, xiaomiPort, command)
    while xiaomiSocket.recvFrom(xdata, xiaomiMsgLen, xaddress, xport) > 0:
      if jn(parseJson(xdata), "cmd") == "read" or isNilOrEmpty(xdata):
        continue
      
      let json = parseJson(xdata)

      let data = jn(json, "data")
      
      if "error" in data:
        when defined(dev):
          echo "DEV: Not a device"
          echo data
        continue
      
      mqttSend("xiaomi", "xiaomi/get_id_list_ack", xdata)
      if getValue(db, sql"SELECT sid FROM xiaomi_devices WHERE sid = ?", sid) == "":
        exec(db, sql"INSERT INTO xiaomi_devices (sid, name, model, short_id) VALUES (?, ?, ?, ?)", sid, sid, jn(json, "model"), jn(json, "short_id"))

      if xiaomi_device != "":
        xiaomi_device.add(",")

      xiaomi_device.add("{\"model\":\"" & jn(json, "model") & "\",")
      xiaomi_device.add("\"sid\":\"" & jn(json, "sid") & "\",")
      xiaomi_device.add("\"short_id\":\"" & jn(json, "short_id") & "\",")
      xiaomi_device.add("\"data\":" & jn(json, "data") & "}")

      break
  
  when defined(dev):
    echo "DEV: \n" & pretty(parseJson("{\"xiaomi_devices\":[" & xiaomi_device & "]}"))

  mqttSend("xiaomi", "xiaomi/get_id_list_ack", "{\"xiaomi_devices\":[" & xiaomi_device & "]}")



proc xiaomiCheckAlarmStatus(sid, value, xdata, alarmStatus: string) {.async.} =
  ## Check if the triggered device should trigger the alarm

  # Check is done before calling the proc
  #if alarmStatus notin ["armAway", "armHome"]:
  #  return

  let statusToTrigger = getValueSafe(db, sql"SELECT value_data FROM xiaomi_devices_data WHERE sid = ? AND triggerAlarm = ?", sid, alarmStatus)

  if statusToTrigger == "":
    return

  let st = parseJson(xdata)

  if statusToTrigger == jn(st, value):

    mqttSend("xiaomi", "alarm", "{\"handler\": \"action\", \"element\": \"xiaomi\", \"action\": \"triggered\", \"sid\": \"" & sid & "\", \"value\": \"" & value & "\", \"data\": " & xdata & "}")

    when defined(dev):
      echo "XiaomiMqtt alarm: " & xdata & "\n"
  
      

proc xiaomiParseMqtt*(payload, alarmStatus: string) {.async.} =
  ## Parse the MQTT

  var js: JsonNode
  try:
    js = if not isNil(payload): parseJson(payload) else: parseJson("{}")
  except JsonParsingError:
    echo "JSON xiaomi error"
    return

  if js == parseJson("{}"):
    echo "parse cheated js"
    return
  
  if js.hasKey("cmd"):

    let cmd = jn(js, "cmd")

    # Skip heatbeat from gateway
    if cmd == "heartbeat":
      if jn(js, "token") != "":
        let sid = jn(js, "sid")
        let token = jn(js, "token")
        var gwExists = ""

        if xiaomiGatewaySid == "":
          xiaomiGatewaySid = getValue(db, sql"SELECT sid FROM xiaomi_api WHERE sid = ?", sid)

        if xiaomiGatewaySid == "":
          discard tryExecSafe(db, sql"INSERT INTO xiaomi_devices (sid, name, model) VALUES (?, ?, ?)", sid, "Gateway", "gateway")
          discard tryExecSafe(db, sql"INSERT INTO xiaomi_api (sid, token) VALUES (?, ?)", sid, token)

          xiaomiGatewaySid = sid

        else:
          discard tryExecSafe(db, sql"UPDATE xiaomi_api SET token = ? WHERE sid = ?", token, sid)

      return


    # Skip data is empty
    let xdata = jn(js, "data")
    if xdata == "":
      return

    # Check for gateway
    let model = jn(js, "model")
    if model == "gateway":
      return

    let sid = jn(js, "sid")
    
    # Check output
    if cmd == "report" or cmd == "read_ack":
      var value = ""

      if "no_motion" in xdata:
        value = "no_motion"

      elif "motion" in xdata:
        value = "motion"
      
      elif "lux" in xdata:
        value = "lux"

      elif "status" in xdata:
        value = "status"

      elif "rgb" in xdata:
        value = "rgb"

      elif "illumination" in xdata:
        value = "illumination"
      
      if value in ["status", "motion"] and value != "no_motion" and alarmStatus in ["armAway", "armHome"]:
        asyncCheck xiaomiCheckAlarmStatus(sid, "status", xdata, alarmStatus)

      # Add message
      mqttSend("xiaomi", "wss/to", "{\"handler\": \"action\", \"element\": \"xiaomi\", \"action\": \"read\", \"sid\": \"" & sid & "\", \"value\": \"" & value & "\", \"data\": " & xdata & "}")

    when defined(dev):
      echo "XiaomiMqtt report: " & payload & "\n"

  else:

    if js["action"].getStr() == "discover":
      let db = conn()
      xiaomiDiscover(db)
    
    elif js["action"].getStr() == "read":
      let value = js["value"].getStr()
  
      xiaomiSendReadCmd(js["sid"].getStr(), value)

    elif js["action"].getStr() == "template":
      let value = js["value"].getStr()

      asyncCheck xiaomiWriteTemplate(db, value)

    when defined(dev):
      echo "XiaomiMqtt wss: " & payload & "\n"

  
proc xiaomiClose*() =
  ## Close connection to multicast

  discard xiaomiSocket.leaveGroup(xiaomiMulticast) == true


proc xiaomiInit*(db: DbConn) =
  ## Initialize socket
  
  xiaomiSocket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  xiaomiSocket.setSockOpt(OptReuseAddr, true)
  xiaomiSocket.bindAddr(xiaomiPort)

  if not xiaomiSocket.joinGroup(xiaomiMulticast):
    echo "could not join multicast group"
    quit()


  xiaomiSocket.enableBroadcast true
  #echo "enabled broadcast for the socket, this is not needet for multicast only!"
  

xiaomiInit(db)
