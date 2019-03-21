import asyncdispatch
import osproc
import parsecfg
from os import getAppDir
from strutils import replace
import ../../resources/utils/common

let dict = loadConf("mqtt_func")
let s_mqttPathSub*    = dict.getSectionValue("MQTT","mqttPathSub")
let s_mqttPathPub*    = dict.getSectionValue("MQTT","mqttPathPub")
let s_mqttIp*         = dict.getSectionValue("MQTT","mqttIp")
let s_mqttPort*       = dict.getSectionValue("MQTT","mqttPort")
let s_mqttUsername*   = dict.getSectionValue("MQTT","mqttUsername")
let s_mqttPassword*   = dict.getSectionValue("MQTT","mqttPassword")

proc setupBaseCmd(): string =
  result = s_mqttPathPub & " -p " & s_mqttPort
  if s_mqttIp != "":
    result.add " -h " & s_mqttIp
  if s_mqttUsername != "":
    result.add " -u " & s_mqttUsername
  if s_mqttPassword != "":
    result.add " -P " & s_mqttPassword

let baseCmd = setupBaseCmd()


proc mqttSend*(clientID, topic, message: string) =
  ## Send <message> to <topic>
  let cmd = baseCmd & " -i " & clientID & " -t " & topic & " -m '" & message & "'"
  discard execCmd(cmd)


proc mqttSendAsync*(clientID, topic, message: string) {.async.} =
  ## Send <message> to <topic>
  let cmd = baseCmd & " -i " & clientID & " -t " & topic & " -m '" & message & "'"
  discard execCmd(cmd)
