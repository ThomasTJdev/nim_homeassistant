# Copyright 2018 - Thomas T. Jarløv

import json, sequtils, strutils, net, asyncdispatch, db_sqlite
import multicast
import nimcrypto
import xiaomi

import ../../resources/database/database
import ../../resources/utils/log_utils
import ../../resources/utils/parsers
import ../../resources/mqtt/mqtt_func


type
  Device = tuple[sid: string, name: string, model: string, alarmvalue: string]
  DeviceAlarm = tuple[sid: string, alarmvalue: string, trigger: string]
  DeviceTemplate = tuple[id: string, sid: string, value_name: string, value_data: string]
  Gateway = tuple[sid: string, name: string, model: string, token: string, password: string, secret: string]


var devices: seq[Device] = @[]
var devicesTemplates: seq[DeviceTemplate] = @[]
var devicesAlarm: seq[DeviceAlarm] = @[]
var gateway: Gateway


## Db connection
var db = conn()
var dbXiaomi = conn("dbXiaomi.db")

## Xiaomi
var xiaomiGatewaySid = ""


template jn(json: JsonNode, data: string): string =
  ## Avoid error when parsing JSON
  try: json[data].getStr() except:""


proc xiaomiLoadDevices() =
  ## Load all devices into seq

  devices = @[]

  let allDevices = getAllRows(dbXiaomi, sql"SELECT sid, name, model FROM xiaomi_devices")

  for row in allDevices:
    devices.add((sid: row[0], name: row[1], model: row[2], alarmvalue: ""))


proc xiaomiLoadDevicesTemplates() =
  ## Load all devices into seq

  devicesTemplates = @[]

  let allDevices = getAllRows(dbXiaomi, sql"SELECT id, sid, value_name, value_data FROM xiaomi_templates")

  for row in allDevices:
    devicesTemplates.add((id: row[0], sid: row[1], value_name: row[2], value_data: row[3]))


proc xiaomiLoadDevicesAlarm() =
  ## Load all devices which trigger the alarm into seq

  devicesAlarm = @[]

  let allDevices = getAllRows(dbXiaomi, sql"SELECT xd.sid, xdd.value_data, xdd.triggerAlarm FROM xiaomi_devices AS xd LEFT JOIN xiaomi_devices_data AS xdd ON xdd.sid = xd.sid WHERE xdd.triggerAlarm != '' AND xdd.triggerAlarm != 'false' AND xdd.triggerAlarm IS NOT NULL")

  for row in allDevices:
    devicesAlarm.add((sid: row[0], alarmvalue: row[1], trigger: row[2]))


proc xiaomiGatewayCreate(gSid, gName, gToken, gPassword, gSecret: string) =
  ## Generates the gateway tuple

  gateway = (sid: gSid, name: gName, model: "gateway", token: gToken, password: gPassword, secret: gSecret)


proc xiaomiGatewayUpdateSecret(gToken = gateway[3]) =
  ## Updates the gateways token and secret

  if gToken.len() == 0 or gateway[4].len() == 0:
    return
  xiaomiSecretUpdate(gateway[4], gToken)
  gateway[3] = gToken
  gateway[5] = xiaomiGatewaySecret


proc xiaomiGatewayUpdatePassword*() =
  ## Update the gateways password.
  ## It is not currently need to use a proc,
  ## but in the future, there will be support
  ## for multiple gateways.

  gateway[4] = getValue(dbXiaomi, sql"SELECT key FROM xiaomi_api")


proc xiaomiSoundPlay*(sid: string, defaultRingtone = "8") =
  ## Send Xiaomi command to start sound

  var volume = "4"
  var ringtone = defaultRingtone
  if "," in defaultRingtone:
    ringtone = split(defaultRingtone, ",")[0]
    volume   = split(defaultRingtone, ",")[1]

  xiaomiGatewaySecret = gateway[5]
  xiaomiWrite(sid, "\"mid\": " & ringtone & ", \"vol\": " & volume)


proc xiaomiSoundStop*(sid: string) =
  ## Send Xiaomi command to stop sound

  xiaomiGatewaySecret = gateway[5]
  xiaomiWrite(sid, "\"mid\": 10000")


proc xiaomiGatewayLight*(sid: string, color = "0") =
  ## Send Xiaomi command to enable gateway light

  xiaomiGatewaySecret = gateway[5]
  xiaomiWrite(sid, "\"rgb\": " & color)


proc xiaomiWriteTemplate*(id: string) =
  ## Write a template to the gateway

  for device in devicesTemplates:
    if device[0] == id:

      case device[2]
      of "ringtone":
        if device[3] == "10000":
          xiaomiSoundStop(device[1])
        elif device[3] != "":
          xiaomiSoundPlay(device[1], device[3])
        else:
          xiaomiSoundPlay(device[1])

      of "rgb":
        if device[3] != "":
          xiaomiGatewayLight(device[1], device[3])
        else:
          xiaomiGatewayLight(device[1])

      else:
        discard

      break

var alarmWaitForReset = false
proc xiaomiCheckAlarmStatus(sid, value, xdata, alarmStatus: string) {.async.} =
  ## Check if the triggered device should trigger the alarm

  let alarmtrigger = jn(parseJson(xdata), value)

  for device in devicesAlarm:
    if device[0] == sid and device[1] == alarmtrigger and device[2] == alarmStatus:
      mqttSend("xiaomi", "alarm", "{\"handler\": \"action\", \"element\": \"xiaomi\", \"action\": \"triggered\", \"sid\": \"" & sid & "\", \"value\": \"" & value & "\", \"data\": " & xdata & "}")
      alarmWaitForReset = true
      logit("xiaomi", "INFO", "xiaomiCheckAlarmStatus(): ALARM = " & xdata)

      break


proc xiaomiDiscoverUpdateDB(clearDB = false) =
  # Updates the database with new devices
  ## TODO: THIS FAILS

  if clearDB:
    exec(dbXiaomi, sql"DELETE FROM xiaomi_devices")

  let devicesJson = xiaomiDiscover()
  let devices     = parseJson(devicesJson)["xiaomi_devices"]
  for device in items(devices):
    let sid = device["sid"].getStr()
    if getValue(dbXiaomi, sql"SELECT sid FROM xiaomi_devices WHERE sid = ?", sid) == "":
      exec(dbXiaomi, sql"INSERT INTO xiaomi_devices (sid, name, model, short_id) VALUES (?, ?, ?, ?)", sid, sid, device["model"].getStr(), device["short_id"].getStr())

  xiaomiLoadDevices()
  xiaomiLoadDevicesTemplates()
  xiaomiLoadDevicesAlarm()


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

  # Get SID
  let sid = jn(js, "sid")

  # Check that payload has command response
  if js.hasKey("cmd"):
    let cmd = jn(js, "cmd")

    # If this is the gateway, get the token and update the secret
    if cmd == "heartbeat" and jn(js, "token") != "":
      let token = jn(js, "token")

      # Create the gateway
      if gateway[0].len() == 0:
        xiaomiGatewayCreate(sid, "Gateway", token, getValue(dbXiaomi, sql"SELECT key FROM xiaomi_api"), "")
        if gateway[4].len() == 0:
          logit("xiaomi", "WARNING", "No API key was found")
        else:
          xiaomiGatewayUpdateSecret()

        # Create gateway in DB
        if getValue(dbXiaomi, sql"SELECT sid FROM xiaomi_api WHERE sid = ?", sid).len() == 0:
          discard tryExec(dbXiaomi, sql"INSERT INTO xiaomi_devices (sid, name, model) VALUES (?, ?, ?)", sid, "Gateway", "gateway")
          discard tryExec(dbXiaomi, sql"INSERT INTO xiaomi_api (sid, token) VALUES (?, ?)", sid, token)

        logit("xiaomi", "DEBUG", "Gateway created")

      else:
        # Update the secret
        xiaomiGatewayUpdateSecret(token)
        logit("xiaomi", "DEBUG", "Gateway secret updated")

      return

    logit("xiaomi", "DEBUG", payload)

    # Skip data is empty
    let xdata = jn(js, "data")
    if xdata == "":
      return

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

      # Check if the alarms needs to ring
      if not alarmWaitForReset and alarmStatus in ["armAway", "armHome"]:
        asyncCheck xiaomiCheckAlarmStatus(sid, "status", xdata, alarmStatus)

      if alarmStatus in ["disarmed"]:
        alarmWaitForReset = false

      # Add message
      mqttSend("xiaomi", "wss/to", "{\"handler\": \"action\", \"element\": \"xiaomi\", \"action\": \"read\", \"sid\": \"" & sid & "\", \"value\": \"" & value & "\", \"data\": " & xdata & "}")


  else:

    logit("xiaomi", "DEBUG", payload)

    case js["action"].getStr()
    of "discover":
      xiaomiDiscoverUpdateDB()

    of "read":
      xiaomiSendRead(js["sid"].getStr())

    of "template":
      xiaomiWriteTemplate(js["value"].getStr())

    of "updatepassword":
      xiaomiGatewayUpdatePassword()

    of "adddevice":
      xiaomiLoadDevices()

    of "updatedevice":
      xiaomiLoadDevices()
      xiaomiLoadDevicesTemplates()
      xiaomiLoadDevicesAlarm()

    of "deletedevice":
      xiaomiLoadDevices()
      xiaomiLoadDevicesTemplates()
      xiaomiLoadDevicesAlarm()

    of "addtemplate":
      xiaomiLoadDevicesTemplates()

    of "deletetemplate":
      xiaomiLoadDevicesTemplates()

    of "reloaddevices":
      xiaomiLoadDevices()
      xiaomiLoadDevicesTemplates()
      xiaomiLoadDevicesAlarm()


xiaomiConnect()
xiaomiLoadDevices()
xiaomiLoadDevicesTemplates()
xiaomiLoadDevicesAlarm()
