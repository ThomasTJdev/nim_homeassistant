# Copyright 2018 - Thomas T. Jarløv

import osproc, strutils, asyncdispatch, json

import ../mqtt/mqtt_func

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