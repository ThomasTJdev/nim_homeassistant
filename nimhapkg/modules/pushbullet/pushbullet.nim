# Copyright 2018 - Thomas T. Jarløv
#
# Todo: Implement nim solution instead of curl

import asyncdispatch

import db_sqlite, osproc, json, strutils, parsecfg
import ../../resources/database/database
import ../../resources/mqtt/mqtt_func


var pushbulletAPI = ""

var db = conn()


proc pushbulletSendCurl(pushType = "note", title = "title", body = "body"): string =
  ## Excecute curl with info to pushbullet api

  let output = execProcess("curl -u " & pushbulletAPI & ": -X POST https://api.pushbullet.com/v2/pushes --header 'Content-Type: application/json' --data-binary '{\"type\": \"" & pushType & "\", \"title\": \"" & title & "\", \"body\": \"" & body & "\"}'")

  return output


template jsonHasKey(data: string): bool =
  ## Check JSON for "error" key
  try:
    if hasKey(parseJson(data), "error"):
      true
    else:
      false
  except:
    false


proc pushbulletHistory(db: DbConn, resp, title, body: string): string =
  ## Adds pushbullet to the history

  if jsonHasKey(resp):
    exec(db, sql"INSERT INTO history (element, identificer, value, error) VALUES (?, ?, ?, ?)", "pushbullet", "send", resp, "1")
    
    mqttSend("wss/to", "pushbullet", "{\"handler\": \"response\", \"value\": \"Pushbullet error\", \"error\": \"true\"}")

  else:
    exec(db, sql"INSERT INTO history (element, identifier, value) VALUES (?, ?, ?)", "pushbullet", "send", "Notification delivered. Title: " & title & " - Body: " & body)
    


proc pushbulletSendDb*(db: DbConn, pushID: string) =
  ## Sends a push from database

  let push = getRow(db, sql"SELECT title, body FROM pushbullet_templates WHERE id = ?", pushID)

  let resp = pushbulletSendCurl("note", push[0], push[1])
  discard pushbulletHistory(db, resp, push[0], push[1])
   


proc pushbulletSendTest*(db: DbConn) =
  ## Sends a test pushmessage

  let resp = pushbulletSendCurl("note", "Test title", "Test body")

  if jsonHasKey(resp):
    mqttSend("pushbullet", "wss/to", "{\"handler\": \"response\", \"value\": \"Pushbullet error\", \"error\": \"true\"}")

  else:
    mqttSend("pushbullet", "wss/to", "{\"handler\": \"response\", \"value\": \"Pushbullet msg send\", \"error\": \"false\"}")



proc pushbulletParseMqtt*(payload: string) =
  ## Receive raw JSON from MQTT and parse it

  let js = parseJson(payload)

  if js["pushid"].getStr() == "test":
    pushbulletSendTest(db)

  else:
    pushbulletSendDb(db, js["pushid"].getStr())


#[
proc pushbulletSend*(pushType, title, body: string) =
  ## Get certificate expiration date in special format
  ##
  ## Returns true and output if success,
  ## Returns false and output if error

  let resp = pushbulletSendCurl("note", title, body)

  discard pushbulletHistory(db, resp, title, body)
]#

#[
proc pushbulletSendWebsocketDb*(db: DbConn, pushID: string): string =
  ## Sends a push from database

  let push = getRow(db, sql"SELECT title, body FROM pushbullet_templates WHERE id = ?", pushID)

  let resp = pushbulletSendCurl("note", push[0], push[1])
  return pushbulletHistory(db, resp, push[0], push[1])
]#

#[
proc pushbulletSendWebsocket*(pushType, title, body: string): string =
  ## Get certificate expiration date in special format
  ##
  ## Returns true and output if success,
  ## Returns false and output if error

  let resp = pushbulletSendCurl("note", title, body)
  return pushbulletHistory(db, resp, title, body)
]#

proc pushbulletUpdateApi*(db: DbConn) =
  pushbulletAPI = getValue(db, sql"SELECT api FROM pushbullet_settings WHERE id = ?", "1")


proc pushbulletNewApi*(db: DbConn, api: string) =
  exec(db, sql"UPDATE pushbullet_settings SET api = ? WHERE id = ?", api, "1")
  pushbulletAPI = api


pushbulletUpdateApi(db)