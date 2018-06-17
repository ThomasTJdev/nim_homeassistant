# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import mqtt
import strutils

import ../mqtt/mqtt_func
import ../xiaomi/xiaomi


proc mqttStartListener() =
  ## Start MQTT listener
  echo "Xiaomi main MQTT listener started"
  
  var mqttClientMainq = newClient(s_address, "mainxiaomilisten", MQTTPersistenceType.None)
  mqttClientMainq.connect(connectOptions)
  mqttClientMainq.subscribe("xiaomi", QOS0)

  while true:
    try:
      var topicName: string
      var message: MQTTMessage
      let timeout = mqttClientMainq.receive(topicName, message, 10000)
      if not timeout:
        asyncCheck xiaomiParseMqtt(message.payload) 
      else:
        discard

    except:
      mqttClientMainq.disconnect(1000)
      mqttClientMainq.destroy()
      quit()
  
  mqttClientMainq.disconnect(1000)
  mqttClientMainq.destroy()

  echo "Xiaomi MQTT exited"


proc listen() =
  mqttStartListener()


when isMainModule:
  listen()
  runForever()