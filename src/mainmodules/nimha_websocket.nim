# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import asynchttpserver
import asyncnet
import db_sqlite
import json
import logging
import os
import osproc
import parsecfg
import strutils
import streams
import times
import websocket

import ../resources/database/database
import ../resources/database/sql_safe
import ../resources/mqtt/mqtt_func
import ../resources/utils/dates


var db = conn()


var msgHi: seq[string] = @[]   


proc wsmsgMessages*(): string =

  if msgHi.len() == 0:
    return ""
    
  var json = ""
  for element in msgHi:
    if json != "":
      json.add("," & element)
    else:
      json.add(element)
  msgHi = @[]

  return "{\"handler\": \"history\", \"data\" :[" & json & "]}"


type
  Client = ref object
    ws: AsyncWebSocket
    socket: AsyncSocket
    connected: bool
    hostname: string
    lastMessage: float
    rapidMessageCount: int
    history: string

  Server = ref object
    clients: seq[Client]
    needsUpdate: bool


# Contains the clients
var server = Server(
    clients: @[]
  )


proc newClient(ws: AsyncWebSocket, socket: AsyncSocket, hostname: string): Client =
  ## Generate the client

  return Client(
    ws: ws,
    socket: socket,
    connected: true,
    hostname: hostname,
    lastMessage: epochTime(),
    history: ""
  )


  
proc updateClientsNow() {.async.} =
  ## Updates clients list

  var newClients: seq[Client] = @[]
  for client in server.clients:
    if not client.connected: 
      continue
    newClients.add(client)

  # Overwrite with new list containing only connected clients.
  server.clients = newClients
  server.needsUpdate = false



proc wsConnectedUsers(): string =
  ## Generate JSON for active users

  var users = ""

  for client in server.clients:
    if not client.connected: 
      continue

    if users != "":
      users.add(",")
    users.add("{\"hostname\": \"" & client.hostname & "\", \"lastMessage\": \"" & epochDate($toInt(client.lastMessage), "DD MMM HH:mm") & "\"}")

  var json = "{\"handler\": \"action\", \"element\": \"websocket\", \"value\": \"connectedusers\", \"users\": [" & users & "]}"
  
  return json



proc wsSendConnectedUsers() {.async.} =
  ## Send JSON with connected users

  msgHi.add(wsConnectedUsers())



proc pong(server: Server) {.async.} =
  ## Send JSON to connected users every nth second.
  ## This is used for to ensure, that the socket
  ## can follow the pace with messages. Without
  ## this it crashes.
  ##
  ## INFO! It is not testet, if this is needed
  ## after changing MQTT input to socket input

  var updateClients = false
  while true:
    let json = wsmsgMessages()
    
    if not isNil(server.clients) and json != "":
      for client in server.clients:

        try:
          if not client.connected: 
            continue
          await client.socket.sendText(json, false)
          
        except:
          echo("WSS: Pong msg failed")
          client.connected = false
          updateClients = true
          continue

    if updateClients:   
      await updateClientsNow()
      updateClients = false
    
    await sleepAsync(1500)


template js(json: string): JsonNode =
  ## Avoid error in parsing JSON

  try:
    parseJson(data)
  except:
    parseJson("{}")


template jn(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON

  try:
    json[data].getStr()
  except:
    ""

proc onRequest*(req: Request) {.async,gcsafe.} =
  ## Per request start listening on socket and
  ## update client list
  ## 
  ## This proc is not gcsafe, but removing pragma
  ## gcsafe corrupts waitFor serve()

  let (ws, error) = await verifyWebsocketRequest(req, "nimha")

  if ws.isNil:
    error("WS negotiation failed: ")
    await req.respond(Http400, "WebSocket negotiation failed: " & error)
    
    req.client.close()
  
  else:
    var hostname = req.hostname
    if req.headers.hasKey("x-forwarded-for"):
      hostname = req.headers["x-forwarded-for"]
    echo "Connection from: " & hostname

    server.clients.add(newClient(ws, req.client, hostname))
    var myClient = server.clients[^1]
    asyncCheck wsSendConnectedUsers()
    
    when defined(dev):
      info("Client connected from ", hostname, " ")
      info("Active users: " & $server.clients.len())
    
    while true:
      
      try:
        let (opcode, data) = await myClient.ws.readData()
        #let (opcode, data) = await readData(myClient.socket, true)

        # WARNING - There is no security check for localhost
        if myClient.hostname == "127.0.0.1":
          msgHi.add(data)
          
        else:

          myClient.lastMessage = epochTime()

          case opcode
          of Opcode.Text:
            let js = js(data)

            # To be removed
            if js == parseJson("{}"):
              echo "WSS: Json failed"
              return

            # Check user access
            let userid = getValueSafeRetry(db, sql"SELECT userid FROM session WHERE ip = ? AND key = ? AND userid = ?", hostname, jn(js, "key"), jn(js, "userid"))
            let userstatus = getValueSafeRetry(db, sql"SELECT status FROM person WHERE id = ?", userid)

            if userstatus notin ["Admin", "Moderator", "Normal"]:
              echo "WSS: Client messed up in sid and userid"
              myClient.connected = false
              break
            
            # Respond
            await myClient.socket.sendText("{\"event\": \"received\"}", false)

            if data == "ping":
              discard
            else:
              asyncCheck mqttSendAsync("wss", jn(parseJson(data), "element"), data)

          of Opcode.Close:
            let (closeCode, reason) = extractCloseData(data)
            echo("socket went away, close code: ", closeCode, ", reason: ", reason)
            myClient.connected = false
            asyncCheck updateClientsNow()
            break
          else: 
            let (closeCode, reason) = extractCloseData(data)
            echo("case else, close code: ", closeCode, ", reason: ", reason)
            myClient.connected = false
            asyncCheck updateClientsNow()

        
      except:
        echo("encountered exception: ", getCurrentExceptionMsg())
        myClient.connected = false
        asyncCheck updateClientsNow()
        break


    await myClient.ws.close()
    myClient.connected = false
    info(".. socket went away.")
  
    


when isMainModule:
  echo "Websocket main started"

  asyncCheck pong(server)


  # Bad solution.. !!!
  var httpServer: AsyncHttpServer
  try:
    httpServer = newAsyncHttpServer()
    asyncCheck serve(httpServer, Port(25437), onRequest)

    runForever()

  except IOError:
    echo "IOError.. damn"
    

  close(httpServer)
