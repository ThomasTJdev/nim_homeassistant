import asyncdispatch
import json
import os
import osproc
import strutils
import streams
import times


var ffmpeg: Process
var usbOn = true
var isRunning = false

discard execCmd("/home/pi/nimha/usbcontrol/usboff.sh")

template jn*(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON
  try:
    json[data].getStr()
  except:
    ""


proc mqttParser(payload: string) {.async.} =
  ## Parse the raw output from Mosquitto sub
  ## and start action

  when defined(dev):
    echo payload

  let topicName = payload.split(" ")[0]
  let message   = parseJson(payload.replace(topicName & " ", ""))

  let status = jn(message, "status")

  if status == "ringing" and not isRunning:
    isRunning = true
    if not usbOn:
      discard execCmd("/home/pi/nimha/usbcontrol/usbon.sh")
      usbOn = true
      sleep(6000) # Waiting time for camera to initialize
    let filename = multiReplace($getTime(), [(":", "-"), ("+", "_"), ("T", "_")])
    ffmpeg = startProcess("ffmpeg -timelimit 900 -f video4linux2 -framerate 25 -video_size 640x480 -i /dev/video1 -f alsa -i plughw:CameraB409241,0 -ar 22050 -ab 64k -strict experimental -acodec aac -vcodec mpeg4 -vb 20M -y /mnt/nimha/media/" & filename & ".mp4", options = {poEvalCommand})

  elif status in ["disarmed", "armAway", "armHome"]:
    isRunning = false
    if running(ffmpeg):
      terminate(ffmpeg)
    if usbOn:
      discard execCmd("/home/pi/nimha/usbcontrol/usboff.sh")
      usbOn = off



let s_mqttPathSub   = "/usr/bin/mosquitto_sub"
let s_mqttPassword  = "secretPassword"
let s_clientName    = "secretUsername"
let s_mqttIp        = "ip"
let s_mqttPort      = "8883"
let s_topic         = "alarminfo"

proc mosquittoSub() =
  var mqttProcess = startProcess(s_mqttPathSub & " -v -t " & s_topic & " -u " & s_clientName & " -P " & s_mqttPassword & " -h " & s_mqttIp & " -p " & s_mqttPort, options = {poEvalCommand})

  while running(mqttProcess):
    asyncCheck mqttParser(readLine(outputStream(mqttProcess)))


mosquittoSub()
quit()