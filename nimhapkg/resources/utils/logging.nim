import strutils, times


template echoLog(element, level, msg: string) =
  echo $now() & " [" & level & "] [" & element & "] " & msg


proc logit*(element, level, msg: string) =
  ## Debug information

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