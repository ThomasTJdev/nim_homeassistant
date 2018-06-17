# Copyright 2018 - Thomas T. Jarløv

import db_sqlite, strutils, json, asyncdispatch, parsecfg
import ../database/database
import ../mqtt/mqtt_func
import ../utils/dates
import ../utils/parsers


var db = conn()


let dict    = loadConfig("config/secret.cfg")
let homeLat = dict.getSectionValue("Home","lat")
let homeLon = dict.getSectionValue("Home","lon")


proc owntracksAddWaypoints(db: DbConn, topic, data: string) {.async.} =
  ## Add owntrack waypoints to DB

  let js = parseJson(data)

  let waypoints = js["waypoints"]
  let deviceID  = split(topic, "/")[2]
  let username  = split(topic, "/")[1]

  for waypoint in items(waypoints):
    if getValue(db, sql"SELECT id FROM owntracks_waypoints WHERE username = ? AND desc = ?", username, waypoint["desc"].getStr()) == "":
      exec(db, sql"INSERT INTO owntracks_waypoints (username, device_id, desc, lat, lon, rad) VALUES (?, ?, ?, ?, ?, ?)", username, deviceID, waypoint["desc"].getStr(), waypoint["lat"].getFloat(), waypoint["lon"].getFloat(), waypoint["rad"].getInt())
    else:
      exec(db, sql"UPDATE owntracks_waypoints SET username = ?, device_id = ?, desc = ?, lat = ?, lon = ?, rad = ? WHERE username = ? AND device_id = ?", username, deviceID, waypoint["desc"].getStr(), waypoint["lat"].getFloat(), waypoint["lon"].getFloat(), waypoint["rad"].getInt(), username, deviceID)



proc owntracksLastLocations(init = false) {.async.} =
  ## Returns the latest owntracks locations for all devices including waypoints

  var json = "{\"handler\": \"action\", \"element\": \"owntracks\""

  # Check type
  if init:
    json.add(", \"value\": \"init\"")
  else:
    json.add(", \"value\": \"refresh\"")

  # Check if home location is defined
  if homeLat != "" and homeLon != "":
    json.add(",\"home\": {\"lat\": \"" & homeLat & "\", \"lon\": \"" & homeLon & "\"}")

  # Get latest history data
  let allLocations = getAllRows(db, sql"SELECT DISTINCT device_id, lat, lon, creation FROM owntracks_history GROUP BY device_id ORDER BY creation DESC")
  if allLocations.len() != 0:
    var moreThanOne = false
    json.add(", \"devices\": [")
    for device in allLocations:
      if moreThanOne:
        json.add(",")

      json.add("{")
      json.add("\"device\": \"" & device[0] & "\",")
      json.add("\"lat\": \"" & device[1] & "\",")
      json.add("\"lon\": \"" & device[2] & "\",")
      json.add("\"date\": \"" & epochDate(device[3], "DD MMM HH:mm") & "\"")
      json.add("}")

      moreThanOne = true

    json.add("]")

  # Get latest history data
  let allWaypoints = getAllRows(db, sql"SELECT DISTINCT desc, lat, lon, rad, creation FROM owntracks_waypoints")
  if allWaypoints.len() != 0:
    var moreThanOne = false
    json.add(", \"waypoints\": [")
    for device in allWaypoints:
      if moreThanOne:
        json.add(",")

      json.add("{")
      json.add("\"desc\": \"" & device[0] & "\",")
      json.add("\"lat\": \"" & device[1] & "\",")
      json.add("\"lon\": \"" & device[2] & "\",")
      json.add("\"rad\": \"" & device[3] & "\",")
      json.add("\"date\": \"" & epochDate(device[4], "DD MMM HH:mm") & "\"")
      json.add("}")

      moreThanOne = true

    json.add("]")
    
  
  json.add("}")

  discard mqttSend("owntracks", "wss/to", json)



proc owntracksHistoryAdd(db: DbConn, topic, data: string) {.async.} =
  ## Add owntrack element to database

  let js = parseJson(data)

  # Assign owntrack data
  let deviceID    = split(topic, "/")[2]
  let username    = split(topic, "/")[1]
  let trackerID   = jn(js, "tid")
  let lat         = jnFloat(js, "lat")
  let lon         = jnFloat(js, "lon")
  let conn        = jn(js, "conn")

  # Check if device exists or add it
  if getValue(db, sql"SELECT device_id FROM owntracks_devices WHERE device_id = ? AND tracker_id = ?", deviceID, trackerID) == "":
    exec(db, sql"INSERT INTO owntracks_devices (device_id, username, tracker_id) VALUES (?, ?, ?)", deviceID, username, trackerID)

  # Add history
  if jn(js, "_type") == "location" and lat != 0 and lon != 0:
    exec(db, sql"INSERT INTO owntracks_history (device_id, username, tracker_id, lat, lon, conn) VALUES (?, ?, ?, ?, ?, ?)", deviceID, username, trackerID, lat, lon, conn)


proc owntracksParseMqtt*(payload: string) {.async.} =
  ## Parse owntracks MQTT

  let js = parseJson(payload)

  if js["value"].getStr() == "init":
    asyncCheck owntracksLastLocations(true)
  else:
    asyncCheck owntracksLastLocations()


proc owntracksDatabase(db: DbConn) =
  ## Creates Xiaomi tables in database

  # Devices
  if not db.tryExec(sql"""
  CREATE TABLE IF NOT EXISTS owntracks_devices (
    username TEXT PRIMARY KEY,
    device_id TEXT,
    tracker_id TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""", []):
    echo " - Owntracks DB: owntracks_devices table already exists"

  # Waypoints
  if not db.tryExec(sql"""
  CREATE TABLE IF NOT EXISTS owntracks_waypoints (
    id INTEGER PRIMARY KEY,
    username TEXT,
    device_id TEXT,
    desc TEXT,
    lat INTEGER,
    lon INTEGER,
    rad INTEGER,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (username) REFERENCES owntracks_devices(username)
  );""", []):
    echo " - Owntracks DB: owntracks_devices table already exists"

  # History
  if not db.tryExec(sql"""
  CREATE TABLE IF NOT EXISTS owntracks_history (
    id INTEGER PRIMARY KEY,
    username TEXT,
    device_id TEXT,
    tracker_id TEXT,
    lat INTEGER,
    lon INTEGER,
    conn VARCHAR(10),
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (username) REFERENCES owntracks_devices(username)
  );""", []):
    echo " - Owntracks DB: owntracks_history table already exists"


owntracksDatabase(db)