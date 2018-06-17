# Copyright 2018 - Thomas T. Jarløv



type
  ## Connection to the Gateway
  WebsocketMessages* = object of RootObj
    text*: string


var wsmsg* {.inject.}: WebsocketMessages
wsmsg.text = ""




proc wsmsgAdd*(data: string) =

  if data == "":
    return

  if wsmsg.text != "":
    wsmsg.text.add(",")

  wsmsg.text.add(data)



proc wsmsgMessages*(): string =

  if wsmsg.text == "":
    #return "{\"pong\": \"nonews\"}"
    return ""

  result = "{\"handler\": \"history\", \"data\" :[" & wsmsg.text & "]}"
  wsmsg.text = ""
  return result


