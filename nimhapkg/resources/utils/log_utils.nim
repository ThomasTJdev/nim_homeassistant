import os, logging, strutils, re, times

let logFile = replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/log/log.log"

discard existsOrCreateDir(replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/log")
if not fileExists(logFile): open(logFile, fmWrite).close()

#var console_logger = newConsoleLogger(fmtStr = verboseFmtStr) # Logs to terminal.
when defined(release):
  var rolling_file_logger = newRollingFileLogger(logFile, levelThreshold = lvlWarn, mode = fmReadWriteExisting, fmtStr = verboseFmtStr)
else:
  var rolling_file_logger = newRollingFileLogger(logFile, mode = fmReadWriteExisting, fmtStr = verboseFmtStr)

addHandler(rolling_file_logger)

template echoLog(element, level, msg: string) =
  echo $now() & " [" & level & "] [" & element & "] " & msg


proc logit*(element, level, msg: string) =
  ## Debug information

  if level in ["WARNING"]:
    warn("[" & element & "] - " & msg)

  if level in ["WARNING", "ERROR"]:
    error("[" & element & "] - " & msg)

  when defined(logoutput) or defined(logxiaomi):
    if element == "xiaomi": echoLog(element, level, msg)

  when defined(logoutput) or defined(logcron):
    if element == "cron": echoLog(element, level, msg)

  when defined(logoutput) or defined(logwsgateway):
    if element == "WSgateway": echoLog(element, level, msg)

  when defined(logoutput) or defined(loggateway):
    if element == "gateway": echoLog(element, level, msg)

  when defined(logoutput) or defined(logwebsocket):
    if element == "websocket": echoLog(element, level, msg)