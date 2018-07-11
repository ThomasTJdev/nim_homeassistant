import asyncdispatch
import osproc
import parsecfg
from os import getAppDir
from strutils import replace

let dict              = loadConfig(replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/config/secret.cfg")
let s_mqttPathSub*    = dict.getSectionValue("MQTT","mqttPathSub")
let s_mqttPathPub*    = dict.getSectionValue("MQTT","mqttPathPub")
let s_mqttIp*         = dict.getSectionValue("MQTT","mqttIp")
let s_mqttPort*       = dict.getSectionValue("MQTT","mqttPort")
let s_mqttUsername*   = dict.getSectionValue("MQTT","mqttUsername")
let s_mqttPassword*   = dict.getSectionValue("MQTT","mqttPassword")



proc mqttSend*(clientID, topic, message: string) = 
  ## Send <message> to <topic>
  
  discard execCmd(s_mqttPathPub & " -i " & clientID & " -t " & topic & " -u " & s_mqttUsername & " -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort & " -m '" & message & "'")
  

proc mqttSendAsync*(clientID, topic, message: string) {.async.} = 
  ## Send <message> to <topic>
  discard execCmd(s_mqttPathPub & " -i " & clientID & " -t " & topic & " -u " & s_mqttUsername & " -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort & " -m '" & message & "'")