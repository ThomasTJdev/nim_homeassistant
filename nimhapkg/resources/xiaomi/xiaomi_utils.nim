# Copyright 2018 - Thomas T. Jarløv

import json, sequtils, strutils, net, asyncdispatch, db_sqlite
import multicast
import nimcrypto
import xiaomi


import ../database/database
import ../database/sql_safe
import ../utils/logging
import ../utils/parsers

import ../mqtt/mqtt_func


## Db connection
var db = conn()

## Xiaomi
var xiaomiGatewaySid = ""


template jn(json: JsonNode, data: string): string =
  ## Avoid error when parsing JSON
  try: json[data].getStr() except:""


proc xiaomiUpdateGatewayPassword*() =
  ## Update the gateways password.
  ## It is not currently need to use a proc,
  ## but in the future, there will be support
  ## for multiple gateways.

  xiaomiGatewayPassword = getValueSafe(db, sql"SELECT key FROM xiaomi_api")


proc xiaomiUpdateToken() =
  ## Updates to the newest token

  xiaomiGatewayToken = getValueSafe(db, sql"SELECT token FROM xiaomi_api")


proc xiaomiSoundPlay*(db: DbConn, sid: string, defaultRingtone = "8") =
  ## Send Xiaomi command to start sound

  var volume = "4"
  var ringtone = defaultRingtone
  if "," in defaultRingtone:
    ringtone = split(defaultRingtone, ",")[0]
    volume   = split(defaultRingtone, ",")[1]

  xiaomiUpdateToken()
  xiaomiWrite(sid, "\"mid\": " & ringtone & ", \"vol\": " & volume, true)


proc xiaomiSoundStop*(db: DbConn, sid: string) =
  ## Send Xiaomi command to stop sound

  xiaomiUpdateToken()
  xiaomiWrite(sid, "\"mid\": 10000", true)
    

proc xiaomiGatewayLight*(db: DbConn, sid: string, color = "0") =
  ## Send Xiaomi command to enable gateway light

  xiaomiUpdateToken()
  xiaomiWrite(sid, "\"rgb\": " & color, true)


proc xiaomiWriteTemplate*(db: DbConn, id: string) =
  ## Write a template to the gateway

  let data = getRowSafe(db, sql"SELECT sid, value_name, value_data FROM xiaomi_templates WHERE id = ?", id)

  if data[0] == "" or data[1] == "":
    return

  case data[1]
  of "ringtone":
    if data[2] == "10000":
      xiaomiSoundStop(db, data[0])
    
    elif data[2] != "":
      xiaomiSoundPlay(db, data[0], data[2])

    else:
      xiaomiSoundPlay(db, data[0])

  of "rgb":
    if data[2] != "":
      xiaomiGatewayLight(db, data[0], data[2])

    else:
      xiaomiGatewayLight(db, data[0])

  else:
    return


proc xiaomiCheckAlarmStatus(sid, value, xdata, alarmStatus: string) {.async.} =
  ## Check if the triggered device should trigger the alarm

  let statusToTrigger = getValueSafe(db, sql"SELECT value_data FROM xiaomi_devices_data WHERE sid = ? AND triggerAlarm = ?", sid, alarmStatus)

  if statusToTrigger == "":
    return

  let st = parseJson(xdata)

  if statusToTrigger == jn(st, value):

    mqttSend("xiaomi", "alarm", "{\"handler\": \"action\", \"element\": \"xiaomi\", \"action\": \"triggered\", \"sid\": \"" & sid & "\", \"value\": \"" & value & "\", \"data\": " & xdata & "}")

    logit("xiaomi", "INFO", "xiaomiCheckAlarmStatus(): ALARM = " & xdata)
    

proc xiaomiDiscoverUpdateDB(clearDB = false) =
  # Updates the database with new devices

  if clearDB:
    exec(db, sql"DELETE FROM xiaomi_devices")

  let devicesJson = xiaomiDiscover()
  let devices     = parseJson(devicesJson)["xiaomi_devices"]
  for device in items(devices):
    let sid = device["sid"].getStr()
    if getValue(db, sql"SELECT sid FROM xiaomi_devices WHERE sid = ?", sid) == "":
      exec(db, sql"INSERT INTO xiaomi_devices (sid, name, model, short_id) VALUES (?, ?, ?, ?)", sid, sid, device["model"].getStr(), device["short_id"].getStr())


proc xiaomiParseMqtt*(payload, alarmStatus: string) {.async.} =
  ## Parse the MQTT

  var js: JsonNode
  try:
    if payload.len() != 0:
      js = parseJson(payload)
    else:
      return
  except JsonParsingError:
    logit("xiaomi", "ERROR", "JSON parsing error")
    return
  
  # Check that payload has command response
  if js.hasKey("cmd"):
    let cmd = jn(js, "cmd")

    # If this is the gateway, get the token
    if jn(js, "cmd") == "heartbeat" and jn(js, "token") != "":
      let sid = jn(js, "sid")
      let token = jn(js, "token")

      if xiaomiGatewaySid == "":
        xiaomiGatewaySid = getValueSafe(db, sql"SELECT sid FROM xiaomi_api WHERE sid = ?", sid)

      if xiaomiGatewaySid == "":
        discard tryExecSafe(db, sql"INSERT INTO xiaomi_devices (sid, name, model) VALUES (?, ?, ?)", sid, "Gateway", "gateway")
        discard tryExecSafe(db, sql"INSERT INTO xiaomi_api (sid, token) VALUES (?, ?)", sid, token)

        xiaomiGatewaySid = sid

        logit("xiaomi", "DEBUG", "Token updated from heartbeat")

      else:
        discard tryExecSafe(db, sql"UPDATE xiaomi_api SET token = ? WHERE sid = ?", token, sid)

      return

    logit("xiaomi", "DEBUG", payload)

    # Skip data is empty
    let xdata = jn(js, "data")
    if xdata == "":
      return

    # Check for gateway <-- Should be done by the heartbeat check
    #let model = jn(js, "model")
    #if model == "gateway":
    #  return

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

      
      if alarmStatus in ["armAway", "armHome"]:
        asyncCheck xiaomiCheckAlarmStatus(sid, "status", xdata, alarmStatus)     

      # Add message
      mqttSend("xiaomi", "wss/to", "{\"handler\": \"action\", \"element\": \"xiaomi\", \"action\": \"read\", \"sid\": \"" & sid & "\", \"value\": \"" & value & "\", \"data\": " & xdata & "}")


  else:

    logit("xiaomi", "DEBUG", payload)

    if js["action"].getStr() == "discover":
      xiaomiDiscoverUpdateDB()
    
    elif js["action"].getStr() == "read":
      let value = js["value"].getStr()
  
      xiaomiSendRead(js["sid"].getStr())

    elif js["action"].getStr() == "template":
      let value = js["value"].getStr()

      xiaomiWriteTemplate(db, value)


xiaomiConnect()
xiaomiUpdateGatewayPassword()