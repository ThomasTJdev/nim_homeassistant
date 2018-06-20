# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import mqtt
import strutils

import ../mqtt/mqtt_func
import ../web/web_utils


proc mqttStartListener() =
  ## Start MQTT listener
  echo "OS main MQTT listener started"
  
  var mqttClientMainq = newClient(s_address, "mainweblisten", MQTTPersistenceType.None)
  mqttClientMainq.connect(connectOptions)
  mqttClientMainq.subscribe("webutils", QOS0)

  while true:
    try:
      var topicName: string
      var message: MQTTMessage
      let timeout = mqttClientMainq.receive(topicName, message, 10000)
      if not timeout:
        asyncCheck webParseMqtt(message.payload) 
        
    except:
      mqttClientMainq.disconnect(1000)
      mqttClientMainq.destroy()
      break

  echo "OS MQTT exited"


when isMainModule:
  mqttStartListener()