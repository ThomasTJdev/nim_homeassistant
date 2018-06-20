# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import mqtt
import strutils

import ../mqtt/mqtt_func
import ../owntracks/owntracks


proc mqttStartListener() =
  ## Start MQTT listener
  echo "Owntracks main MQTT listener started"
  
  var mqttClientMainq = newClient(s_address, "mainowntrackslisten", MQTTPersistenceType.None)
  mqttClientMainq.connect(connectOptions)
  mqttClientMainq.subscribe("owntracks", QOS0)

  while true:
    try:
      var topicName: string
      var message: MQTTMessage
      let timeout = mqttClientMainq.receive(topicName, message, 10000)
      if not timeout:
        asyncCheck owntracksParseMqtt(message.payload) 
        
    except:
      mqttClientMainq.disconnect(1000)
      mqttClientMainq.destroy()
      break


  echo "Owntracks MQTT exited"


when isMainModule:
  mqttStartListener()