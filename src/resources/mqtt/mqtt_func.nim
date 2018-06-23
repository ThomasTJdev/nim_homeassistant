import asyncdispatch
import osproc
import parsecfg

let dict              = loadConfig("config/secret.cfg")
let s_mqttIp*         = dict.getSectionValue("MQTT","mqttIp")
let s_mqttPort*       = dict.getSectionValue("MQTT","mqttPort")
let s_mqttUsername*   = dict.getSectionValue("MQTT","mqttUsername")
let s_mqttPassword*   = dict.getSectionValue("MQTT","mqttPassword")



proc mqttSend*(clientID, topic, message: string) = 
  ## Send <message> to <topic>
  
  discard execCmd("/usr/bin/mosquitto_pub -i " & clientID & " -t " & topic & " -u " & s_mqttUsername & " -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort & " -m '" & message & "'")
  

proc mqttSendAsync*(clientID, topic, message: string) {.async.} = 
  ## Send <message> to <topic>
  discard execCmd("/usr/bin/mosquitto_pub -i " & clientID & " -t " & topic & " -u " & s_mqttUsername & " -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort & " -m '" & message & "'")