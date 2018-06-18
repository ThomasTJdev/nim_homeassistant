# Copyright 2018 - Thomas T. Jarløv

# Copyright 2018 - Thomas T. Jarløv

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
        echo message.payload
        asyncCheck webParseMqtt(message.payload) 
        
    except:
      mqttClientMainq.disconnect(1000)
      mqttClientMainq.destroy()
      quit()

  mqttClientMainq.disconnect(1000)
  mqttClientMainq.destroy()

  echo "OS MQTT exited"


proc listen() =
  mqttStartListener()


when isMainModule:
  listen()
  runForever()