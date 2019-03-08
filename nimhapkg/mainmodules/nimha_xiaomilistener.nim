# Copyright 2018 - Thomas T. Jarløv
import xiaomi

import ../resources/mqtt/mqtt_func
import ../resources/utils/log_utils


proc xiaomiListen() =
  ## Listen for Xiaomi

  xiaomiConnect()

  while true:
      mqttSend("xiaomilisten", "xiaomi", xiaomiReadMessage())

  xiaomiDisconnect()


when isMainModule:
  logit("xiaomi", "INFO", "Xiaomi multicast listener is started")
  xiaomiListen()