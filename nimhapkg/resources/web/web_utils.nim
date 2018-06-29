# Copyright 2018 - Thomas T. Jarløv

# Copyright 2018 - Thomas T. Jarløv

import osproc, strutils, asyncdispatch, json

import ../database/database
import ../mqtt/mqtt_func
import ../web/web_certs

var db = conn()

proc webParseMqtt*(payload: string) {.async.} =
  ## Parse OS utils MQTT
  
  let js = parseJson(payload)

  if js["item"].getStr() == "certexpiry":
    if js.hasKey("server"):
      asyncCheck certExpiraryJson(js["server"].getStr(), js["port"].getStr())
    
    else:
      asyncCheck certExpiraryAll(db)

certDatabase(db)