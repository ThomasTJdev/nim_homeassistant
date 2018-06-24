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

import ../database/database
import ../mail/mail
import ../mqtt/mqtt_func
import ../pushbullet/pushbullet
import ../users/password
import ../xiaomi/xiaomi


var alarmStatus = ""
var alarmArmedTime = toInt(epochTime())

var db = conn()



template jn(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON

  try:
    json[data].getStr()
  except:
    ""



proc alarmAction(db: DbConn, state: string) {.async.} =
  ## Run the action based on the alarm state

  let alarmActions = getAllRows(db, sql"SELECT action, action_ref FROM alarm_actions WHERE alarmstate = ?", state)

  if alarmActions.len() == 0:
    return

  for row in alarmActions:
    when defined(dev):
      echo "Alarm action: " & row[0] & " - id: " & row[1]

    if row[0] == "pushbullet":
      asyncCheck pushbulletSendDb(db, row[1])

    elif row[0] == "mail":
      asyncCheck sendMailDb(db, row[1])

    elif row[0] == "xiaomi":
      asyncCheck xiaomiWriteTemplate(db, row[1])



proc alarmSetStatus(db: DbConn, newStatus, trigger, device: string) =
  # Check that doors, windows, etc are ready
  # Missing user_id

  asyncCheck alarmAction(db, newStatus)

  discard tryExec(db, sql"INSERT INTO alarm_history (status, trigger, device) VALUES (?, ?, ?)", newStatus, trigger, device)

  discard tryExec(db, sql"UPDATE alarm SET status = ? WHERE id = ?", newStatus, "1")

  alarmStatus = newStatus



proc alarmRinging*(db: DbConn, trigger, device: string) {.async.} =
  ## The alarm is ringing

  when defined(dev):
    echo "Alarm: Status = ringing"

  alarmSetStatus(db, "ringing", trigger, device)

  mqttSend("alarm", "wss/to", "{\"handler\": \"action\", \"element\": \"alarm\", \"action\": \"setstatus\", \"value\": \"ringing\"}")


proc alarmTriggerTimer(cd: string) {.async.} = 
  ## The alarm countdown timer
  ## Currently used for not blocking to much..
  ## 
  ## To be changed

  var counter = 0
  while true:
    await sleepAsync(1000)
    inc(counter)
    
    when defined(dev):
      echo "Alarm countdown: " & $counter & "/" & cd

    if counter == parseInt(cd) or alarmStatus != "triggered":
      break



proc alarmTriggered*(db: DbConn, trigger, device: string) {.async.} =
  ## The alarm has been triggereds
  # Missing user_id

  when defined(dev):
    echo "Alarm: Status = triggered"

  # Check if the armtime is done and
  # activate the alarm
  let armTime = parseInt(getValue(db, sql"SELECT value FROM  alarm_settings WHERE element = ?", "armtime")) + alarmArmedTime

  if armTime > toInt(epochTime()):
    when defined(dev):
      echo "Alarm: Triggered alarm cancelled to due to armtime"
    return

  # Send info about the alarm is triggered
  mqttSend("alarm", "wss/to", "{\"handler\": \"action\", \"element\": \"alarm\", \"action\": \"setstatus\", \"value\": \"triggered\"}")

  # Change the alarm status
  alarmSetStatus(db, "triggered", trigger, device)

  # Add to history
  exec(db, sql"INSERT INTO alarm_history (status, trigger, device) VALUES (?, ?, ?)", "triggered", trigger, device)

  # Start the countdown
  var countDown = getValue(db, sql"SELECT value FROM alarm_settings WHERE element = ?", "countdown")

  when defined(dev):
    echo "Alarm: Countdown starting, " & countDown

  var f = alarmTriggerTimer(countDown)
  while not f.finished:
    poll(1000)
    
  if f.finished:
    if alarmStatus == "triggered":
      asyncCheck alarmRinging(db, trigger, device)



proc alarmGetStatus*(db: DbConn): string =
  ## Get alarm status

  return getValue(db, sql"SELECT status FROM alarm WHERE id = ?", "1")



proc alarmParseMqtt*(payload: string) {.async.} =
  ## Parse MQTT

  var js = parseJson(payload)

  let action = jn(js, "action")

  if action == "triggered" and alarmStatus in ["armAway", "armHome"]:
    asyncCheck alarmTriggered(db, jn(js, "value"), jn(js, "sid"))

  elif action == "activate":
    var passOk = false
    let passwordEnabled = getAllRows(db, sql"SELECT id FROM alarm_password")

    if passwordEnabled.len() > 0:
      let password = jn(js, "password")

      for row in fastRows(db, sql"SELECT password, salt FROM alarm_password WHERE userid = ?", jn(js, "userid")):
        if row[0] == makePassword(password, row[1], row[0]):
          passOk = true

    else:
      passOk = true

    if not passOk:
      mqttSend("alarm", "wss/to", "{\"handler\": \"response\", \"value\": \"Wrong alarm password\", \"error\": \"true\"}")
      return      

    let status = jn(js, "status")
    
    if status in ["armAway", "armHome"]:
      alarmSetStatus(db, status, "user", "")
    
    elif status == "disarmed":
      alarmArmedTime = toInt(epochTime())
      alarmSetStatus(db, status, "user", "")


    mqttSend("alarm", "wss/to", "{\"handler\": \"action\", \"element\": \"alarm\", \"action\": \"setstatus\", \"value\": \"" & status & "\"}")


proc alarmInit*(db: DbConn) =
  ## Set alarm status
  
  alarmStatus = getValue(db, sql"SELECT status FROM alarm WHERE id = ?", "1")



alarmInit(db)