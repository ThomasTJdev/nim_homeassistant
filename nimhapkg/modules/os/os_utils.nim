# Copyright 2018 - Thomas T. Jarløv

import osproc, strutils, asyncdispatch, json, db_sqlite

import ../../resources/database/database
import ../../resources/mqtt/mqtt_func
import ../../resources/utils/logging

var db = conn()
var dbOs = conn("dbOs.db")


proc osFreeMem*(): string =
  return execProcess("free -m | awk 'NR==2{print $4}'")

proc osFreeSwap*(): string =
  return execProcess("free -m | awk 'NR==3{print $4}'")

proc osUsedMem*(): string =
  return execProcess("free -m | awk 'NR==2{print $3}'")

proc osUsedSwap*(): string =
  return execProcess("free -m | awk 'NR==3{print $3}'")

proc osConnNumber*(): string =
  return execProcess("netstat -ant | grep ESTABLISHED | wc -l")

proc osHostIp*(): string =
  return  execProcess("hostname --ip-address")

proc osData*(): string =
  result = "{\"handler\": \"action\", \"element\": \"osstats\", \"action\": \"read\", \"freemem\": \"" & osFreeMem() & "\", \"freeswap\": \"" & osFreeSwap() & "\", \"usedmem\": \"" & osUsedMem() & "\", \"usedswap\": \"" & osUsedSwap() & "\", \"connections\": \"" & osConnNumber() & "\", \"hostip\": \"" & osHostIp() & "\"}"

  return replace(result, "\n", "")


proc osParseMqtt*(payload: string) {.async.} =
  ## Parse OS utils MQTT

  let js = parseJson(payload)

  if js["value"].getStr() == "refresh":
    mqttSend("os", "wss/to", osData())


proc osRunCommand*(command: string) =
  ## Run os template command

  if execCmd(command) == 1:
    logit("osutils", "ERROR", "Command failed: " & command)


proc osRunTemplate*(osID: string) {.async.} =
  ## Run os template command

  let command = getValue(dbOs, sql("SELECT command FROM os_templates WHERE id = ?"), osID)
  if execCmd(command) == 1:
    logit("osutils", "ERROR", "Command failed: " & command)