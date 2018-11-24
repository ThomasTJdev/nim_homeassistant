# Copyright 2018 - Thomas T. Jarløv
#
## Alarm module
##
## Available alarm status:
## - disarmed
## - armAway
## - armHome
## - triggered
## - ringing

import parsecfg, db_sqlite, strutils, asyncdispatch, json, times

import ../../resources/database/database
import ../../resources/mqtt/mqtt_func
import ../../resources/mqtt/mqtt_templates
import ../../resources/users/password
import ../../resources/utils/logging
import ../mail/mail
import ../pushbullet/pushbullet
when defined(rpi):
  import ../rpi/rpi_utils
import ../xiaomi/xiaomi_utils



type
  Alarm = tuple[status: string, armtime: string, countdown: string, armedtime: string]
  AlarmPasswords = tuple[userid: string, password: string, salt: string]
  AlarmActions = tuple[id: string, action: string, action_ref: string, alarmstate: string]

var alarm*: Alarm
var alarmPasswords: seq[AlarmPasswords] = @[]
var alarmActions: seq[AlarmActions] = @[]


var db = conn()


proc alarmLoadStatus() =
  ## Load alarm status

  let aStatus = getValue(db, sql"SELECT status FROM alarm WHERE id = ?", "1")
  let aArmtime = getValue(db, sql"SELECT value FROM alarm_settings WHERE element = ?", "armtime")
  let aCountdown = getValue(db, sql"SELECT value FROM alarm_settings WHERE element = ?", "countdown")

  alarm = (status: aStatus, armtime: aArmtime, countdown: aCountdown, armedtime: $toInt(epochTime()))


proc alarmLoadPasswords() =
  ## Load the alarm passwords

  alarmPasswords = @[]

  let allPasswords = getAllRows(db, sql"SELECT userid, password, salt FROM alarm_password ")
  for row in allPasswords:
    alarmPasswords.add((userid: row[0], password: row[1], salt: row[2]))


proc alarmLoadActions() =
  ## Load the alarm passwords

  alarmActions = @[]

  let allActions = getAllRows(db, sql"SELECT id, action, action_ref, alarmstate FROM alarm_actions")
  for row in allActions:
    alarmActions.add((id: row[0], action: row[1], action_ref: row[2], alarmstate: row[3]))


template jn(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON
  try: json[data].getStr() except: ""


proc alarmAction() =
  ## Run the action based on the alarm state

  for action in alarmActions:
    if action[3] == alarm[0]:
      logit("alarm", "DEBUG", "alarmAction(): " & action[1] & " - id: " & action[2])

      case action[1]
      of "pushbullet":
        pushbulletSendDb(db, action[2])
      of "mail":
        sendMailDb(db, action[2])
      of "mqtt":
        mqttActionSendDb(db, action[2])
      of "rpi":
        when defined(rpi):
          discard rpiAction(action[2])
      of "xiaomi":
        xiaomiWriteTemplate(db, action[2])


proc alarmSetStatus(newStatus, trigger, device: string, userID = "") =
  # Check that doors, windows, etc are ready

  asyncCheck mqttSendAsync("alarm", "alarminfo", "{\"action\": \"iotinfo\", \"element\": \"alarm\", \"status\": \"" & newStatus & "\", \"value\": \"\"}")

  alarm[0] = newStatus
  exec(db, sql"UPDATE alarm SET status = ?", newStatus)

  if userID != "":
    discard tryExec(db, sql"INSERT INTO alarm_history (status, trigger, device, userid) VALUES (?, ?, ?, ?)", newStatus, trigger, device, userID)
  else:
    discard tryExec(db, sql"INSERT INTO alarm_history (status, trigger, device) VALUES (?, ?, ?)", newStatus, trigger, device)

  alarmAction()


proc alarmRinging*(db: DbConn, trigger, device: string) =
  ## The alarm is ringing

  logit("alarm", "INFO", "alarmRinging(): Status = ringing")

  alarmSetStatus("ringing", trigger, device)

  mqttSend("alarm", "wss/to", "{\"handler\": \"action\", \"element\": \"alarm\", \"action\": \"setstatus\", \"value\": \"ringing\"}")


proc alarmTriggered*(db: DbConn, trigger, device: string) =
  ## The alarm has been triggereds

  logit("alarm", "INFO", "alarmTriggered(): Status = triggered")

  # Check if the armtime is over
  let armTimeOver = parseInt(alarm[1]) + parseInt(alarm[3])
  if armTimeOver > toInt(epochTime()):
    logit("alarm", "INFO", "alarmTriggered(): Triggered alarm cancelled to due to armtime")
    return

  else:
    logit("alarm", "INFO", "alarmTriggered(): Triggered alarm true - armtime done")

  # Change the alarm status
  #alarmSetStatus("triggered", trigger, device)

  # Send info about the alarm is triggered
  #mqttSend("alarm", "wss/to", "{\"handler\": \"action\", \"element\": \"alarm\", \"action\": \"setstatus\", \"value\": \"triggered\"}")

  ############
  # Due to non-working async trigger countdown (sleepAsync), it's skipped at the moment
  ############

  alarmRinging(db, trigger, device)


proc alarmParseMqtt*(payload: string) {.async.} =
  ## Parse MQTT message

  let js = parseJson(payload)
  let action = jn(js, "action")


  if action == "adddevice":
    alarmLoadActions()

  elif action == "deletedevice":
    alarmLoadActions()

  elif action == "updatealarm":
    alarmLoadStatus()

  elif action == "updateuser":
    alarmLoadPasswords()

  elif action == "triggered" and alarm[0] in ["armAway", "armHome"]:
    alarmTriggered(db, jn(js, "value"), jn(js, "sid"))

  elif action == "activate":
    let userID = jn(js, "userid")
    var passOk = false

    # Check passwords
    if alarmPasswords.len() > 0:
      let passwordUser = jn(js, "password")

      for password in alarmPasswords:
        if userID == password[0]:
          if password[1] == makePassword(passwordUser, password[2], password[1]):
            passOk = true

    else:
      # If there's no password protection - accept
      passOk = true

    if not passOk:
      mqttSend("alarm", "wss/to", "{\"handler\": \"response\", \"value\": \"Wrong alarm password\", \"error\": \"true\"}")
      return

    let status = jn(js, "status")

    if status in ["armAway", "armHome"]:
      alarm[3] = $toInt(epochTime())
      alarmSetStatus(status, "user", "", userID)

    elif status == "disarmed":
      alarm[3] = $toInt(epochTime())
      alarmSetStatus(status, "user", "", userID)

    mqttSend("alarm", "wss/to", "{\"handler\": \"action\", \"element\": \"alarm\", \"action\": \"setstatus\", \"value\": \"" & status & "\"}")


## Load alarm data
alarmLoadStatus()
alarmLoadPasswords()
alarmLoadActions()