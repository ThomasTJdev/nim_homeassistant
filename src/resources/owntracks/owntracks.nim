# Copyright 2018 - Thomas T. Jarløv

import db_sqlite, strutils, json, asyncdispatch, parsecfg
import ../database/database
import ../mqtt/mqtt_func
import ../utils/dates
import ../utils/parsers

from os import getAppDir

var db = conn()


let dict    = loadConfig(replace(getAppDir(), "/src/mainmodules", "") & "/config/secret.cfg")
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
  
  mqttSend("owntracks", "wss/to", json)



proc owntracksHistoryAdd(topic, data: string) {.async.} =
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


proc owntracksParseMqtt*(payload, topic: string) {.async.} =
  ## Parse owntracks MQTT

  let js = parseJson(payload)

  # Update with last location
  if hasKey(js, "_type"):
    asyncCheck owntracksHistoryAdd(topic, payload)

  # Send data to websocket
  elif js["value"].getStr() == "init":
    asyncCheck owntracksLastLocations(true)

  else:
    asyncCheck owntracksLastLocations()

