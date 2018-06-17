import mqtt
import os
import asyncdispatch
import parsecfg


let dict        = loadConfig("config/secret.cfg")
let s_address*   = dict.getSectionValue("MQTT","mqttAddress")
let s_username  = dict.getSectionValue("MQTT","mqttUsername")
let s_password  = dict.getSectionValue("MQTT","mqttPassword")


var mqttClient* = newClient("", "", MQTTPersistenceType.None)
var connectOptions* = newConnectOptions()
connectOptions.username = s_username
connectOptions.password = s_password


proc mqttSend*(clientID, topic, message: string): bool = 
  ## Send <message> to <topic>

  try:
    mqttClient = newClient(s_address, clientID, MQTTPersistenceType.None)
    connectOptions.keepAliveInterval = 20

    mqttClient.connect(connectOptions)
    discard mqttClient.publish(topic, message, QOS.AtMostOnce, false)
    mqttClient.disconnect(1000)
    mqttClient.destroy()
    return true
  except MQTTError:
    echo "MQTT exception: " & getCurrentExceptionMsg()
    return false


proc mqttSendAsync*(clientID, topic, message: string) {.async.} = 
  ## Send <message> to <topic>

  try:
    mqttClient = newClient(s_address, clientID, MQTTPersistenceType.None)
    connectOptions.keepAliveInterval = 20

    mqttClient.connect(connectOptions)
    discard mqttClient.publish(topic, message, QOS.AtMostOnce, false)
    mqttClient.disconnect(1000)
    mqttClient.destroy()
  except MQTTError:
    echo "MQTT exception: " & getCurrentExceptionMsg()


proc mqttListen*(topic = "#") {.async.} = 
  ## Listen on MQTT
  ## If no topic is specified, listen on everything (#)

  try:
    mqttClient = newClient(s_address, "s_clientID", MQTTPersistenceType.None)
    mqttClient.connect(connectOptions)
    mqttClient.subscribe("#", QOS0)
    while true:
      var topicName: string
      var message: MQTTMessage
      let timeout = mqttClient.receive(topicName, message, 10000)
      if not timeout:
        echo message.payload
        echo topicName
        echo message
      
    mqttClient.disconnect(1000)
    mqttClient.destroy()
  except MQTTError:
    quit "MQTT exception: " & getCurrentExceptionMsg()




proc mqttListenInit*(clientID: string, topic = "#"): (bool, string) = 
  ## Prepare and init the MQTT connection

  try:
    mqttClient = newClient(s_address, clientID, MQTTPersistenceType.None)
    mqttClient.connect(connectOptions)
    mqttClient.subscribe("#", QOS0)
    return (true, "")

  except MQTTError:
    return (false, getCurrentExceptionMsg())



proc mqttEstablishAsyncConn*(clientID: string): untyped =
  ## Establish connection to MQTT

  mqttClient = newClient(s_address, clientID, MQTTPersistenceType.None)
  mqttClient.connect(connectOptions)
  return mqttClient


proc mqttListenClose*() = 
  ## Close the MQTT connection

  try:
    mqttClient.disconnect(1000)
    mqttClient.destroy()

  except MQTTError:
    echo getCurrentExceptionMsg()
