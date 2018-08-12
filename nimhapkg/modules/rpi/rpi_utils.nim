# Copyright 2018 - Thomas T. Jarløv

import wiringPiNim
import asyncdispatch
import strutils
import json
import db_sqlite

from osproc import execProcess

import ../../resources/database/database
import ../../resources/mqtt/mqtt_func
import ../../resources/utils/logging

type 
  RpiTemplate = tuple[id: string, name: string, pin: string, pinMode: string, pinPull: string, digitalAction: string, analogAction: string, value: string]

var rpiTemplate: seq[RpiTemplate] = @[]

var db = conn()


proc rpiLoadTemplates*() =
  ## Load the RPi templates

  rpiTemplate = @[]

  let allRpi = getAllRows(db, sql"SELECT id, name, pin, pinMode, pinPull, digitalAction, analogAction, value FROM rpi_templates")

  for rpi in allRpi:
    rpiTemplate.add((id: rpi[0], name: rpi[1], pin: rpi[2], pinMode: rpi[3], pinPull: rpi[4], digitalAction: rpi[5], analogAction: rpi[6], value: rpi[7]))


proc rpiAction*(rpiID: string): string =
  ## Run the RPi template

  for rpi in rpiTemplate:
    if rpi[0] != rpiID:
      continue
    
    if rpi[2].len() == 0:
      return
    let rpiPin = toU32(parseInt(rpi[2]))


    # Setup RPi
    #if piSetup() < 0:
    #  return


    # Set pin mode
    if rpi[3].len() != 0:
      case rpi[3]
      of "gpio":
        piPinModeGPIO(rpiPin)
      of "pwm":
        piPinModePWM(rpiPin)
      of "output":
        piPinModeOutput(rpiPin)
      of "input":
        piPinModeInput(rpiPin)
      else:
        discard


    # Pull pin
    if rpi[4].len() != 0:
      case rpi[4]
      of "off":
        piPullOff(rpiPin)
      of "down":
        piPullDown(rpiPin)
      of "up":
        piPullUp(rpiPin)
      else:
        discard


    # Read or write
    # Digital:
    let value = toU32(parseInt(rpi[1]))
    if rpi[5].len() != 0:
      case rpi[5]
      of "pwm":
        piDigitalPWM(rpiPin, value)
      of "write":
        piDigitalWrite(rpiPin, value)
      of "read":
        return $piDigitalRead(rpiPin)
      else:
        discard
    
    # Analog:
    elif rpi[6].len() != 0:
      case rpi[6]
      of "write":
        analogWrite(rpiPin, value)
      of "read":
        return $analogRead(rpiPin)
      else:
        discard
    

proc rpiParseMqtt*(payload: string) {.async.} =
  let js = parseJson(payload)

  if js["action"].getStr() == "runtemplate":
    let rpiID = js["rpiid"].getStr()
    let rpiOutput = rpiAction(rpiID)

    mqttSend("rss", "wss/to", "{\"handler\": \"action\", \"element\": \"rpi\", \"action\": \"template\", \"output\": \"" & rpiOutput & "\"}")

  elif js["action"].getStr() == "write":
    let rpiID = js["rpiid"].getStr()
    let rpiOutput = rpiAction(rpiID)



proc rpiInit() =
  ## Init RPi setup

  let gpioExists = execProcess("gpio -readall")
  if gpioExists.len() == 0:
    logit("rpi", "DEBUG", "piSetup(): Setup failed")
    return

  for line in split(gpioExists, "\n"):
    if "Oops" in line:
      logit("rpi", "DEBUG", "piSetup(): Setup failed")
      return

  rpiLoadTemplates()
  logit("rpi", "DEBUG", "piSetup(): Setup complete")
  

rpiInit()