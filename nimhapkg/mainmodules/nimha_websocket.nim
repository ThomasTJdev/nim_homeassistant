# Copyright 2018 - Thomas T. Jarløv

## Websocket for communicating with browser.
## Data is delivered from a websocket client
## on 127.0.0.1. Data is sent within a static
## loop every 1,5 second to the browser.

import asyncdispatch
import asynchttpserver
import asyncnet
import db_sqlite
import json
import os
import osproc
import parsecfg
import random
import re
import sequtils
import strutils
import streams
import times
import websocket

import ../resources/database/database
import ../resources/mqtt/mqtt_func
import ../resources/users/password
import ../resources/utils/dates
import ../resources/utils/log_utils


type
  Client = ref object
    ws: AsyncWebSocket
    socket: AsyncSocket
    connected: bool
    hostname: string
    lastMessage: float
    history: string
    wsSessionStart: int
    key: string
    userStatus: string

  Server = ref object
    clients: seq[Client]
    needsUpdate: bool

  #Users = tuple[userid: string, ip: string, key: string, status: string]

# Contains the clients
var server = Server(clients: @[])

# Contains the user data
#var users: seq[Users] = @[]


# Set key for communication without verification on 127.0.0.1
const rlAscii  = toSeq('a'..'z')
const rhAscii  = toSeq('A'..'Z')
const rDigit  = toSeq('0'..'9')
randomize()
var localhostKey = ""
for i in countUp(1, 62):
  case rand(2)
  of 0: localhostKey.add(rand(rlAscii))
  of 1: localhostKey.add(rand(rhAscii))
  of 2: localhostKey.add(rand(rDigit))
  else: discard
let localhostKeyLen = localhostKey.len()
for fn in [replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/config/secret.cfg"]:
  # When using setSectionKey formatting and comments are deleted..
  fn.writeFile fn.readFile.replace(re("wsLocalKey = \".*\""), "wsLocalKey = \"" & localhostKey & "\"")



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

#[
proc loadUsers() =
  ## Load the user data

  users = @[]

  let allUsers = getAllRows(db, sql"SELECT session.userid, session.password, session.salt, person.status FROM session LEFT JOIN person ON person.id = session.userid")
  for row in allUsers:
    users.add((userid: row[0], ip: row[1], key: row[2], status: row[3]))


template checkUserAccess(hostname, key, userID: string) =
  ## Check if the user (requester) has access

  var access = false

  for user in users:
    if user[0] == userID and hostname == user[1] and key == user[2] and status in ["Admin", "Moderator", "Normal"]:
      access = true
      break

  if not access:
    break
]#


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

  var updateClients = false
  while true:
    let json = wsmsgMessages()

    if server.clients.len() != 0 and json != "":
      for client in server.clients:

        try:
          if not client.connected:
            continue
          await client.ws.sendText(json)

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
    logit("websocket", "ERROR", "WS negotiation failed")
    await req.respond(Http400, "WebSocket negotiation failed: " & error)

    req.client.close()

  else:
    var hostname = req.hostname
    if req.headers.hasKey("x-forwarded-for"):
      hostname = req.headers["x-forwarded-for"]
    logit("websocket", "INFO", "Connection from: " & hostname)

    server.clients.add(newClient(ws, req.client, hostname))
    var myClient = server.clients[^1]
    asyncCheck wsSendConnectedUsers()

    when defined(dev):
      logit("websocket", "INFO", "Client connected from: " & hostname)
      logit("websocket", "INFO", "Active users: " & $server.clients.len())

    while true:

      try:
        let (opcode, data) = await myClient.ws.readData()
        #let (opcode, data) = await readData(myClient.socket, true)

        if myClient.hostname == "127.0.0.1" and data.substr(0, localhostKeyLen-1) == localhostKey:
          logit("websocket", "DEBUG", "127.0.0.1 message: " & data.substr(localhostKeyLen, data.len()))
          msgHi.add(data.substr(localhostKeyLen, data.len()))

        else:

          myClient.lastMessage = epochTime()

          case opcode
          of Opcode.Text:
            let js = js(data)

            # To be removed
            if js == parseJson("{}"):
              logit("websocket", "ERROR", "Parsing JSON failed")
              return

            # Check user access. Current check is set to every 5 minutes (300s) - if user account is deleted, connection will be terminated
            if myClient.wsSessionStart + 300 < toInt(epochTime()) or myClient.key == "" or myClient.userStatus == "":
              let key = jn(js, "key")
              let userid = getValue(db, sql"SELECT userid FROM session WHERE ip = ? AND key = ? AND userid = ?", hostname, key, jn(js, "userid"))
              myClient.userStatus = getValue(db, sql"SELECT status FROM person WHERE id = ?", userid)
              myClient.wsSessionStart = toInt(epochTime())
              myClient.key = key

            if myClient.userStatus notin ["Admin", "Moderator", "Normal"]:
              logit("websocket", "ERROR", "Client messed up in sid and userid")
              myClient.connected = false
              asyncCheck updateClientsNow()
              break

            # Respond
            await myClient.ws.sendText("{\"event\": \"received\"}")

            if data == "ping":
              discard
            else:
              logit("websocket", "DEBUG", "Client message: " & data)
              asyncCheck mqttSendAsync("wss", jn(parseJson(data), "element"), data)

          of Opcode.Close:
            let (closeCode, reason) = extractCloseData(data)
            logit("websocket", "INFO", "Socket went away, close code: " & $closeCode & ", reason: " & $reason)
            myClient.connected = false
            asyncCheck updateClientsNow()
            break
          else:
            let (closeCode, reason) = extractCloseData(data)
            logit("websocket", "INFO", "Case else, close code: " & $closeCode & ", reason: " & $reason)
            myClient.connected = false
            asyncCheck updateClientsNow()


      except:
        logit("websocket", "ERROR", "Encountered exception: " & getCurrentExceptionMsg())
        myClient.connected = false
        asyncCheck updateClientsNow()
        break


    myClient.connected = false
    myClient.key = ""
    myClient.userStatus = ""
    try:
      await myClient.ws.close()
      logit("websocket", "INFO", ".. socket went away.")
    except:
      logit("websocket", "INFO", ".. socket went away but couldn't close it")




when isMainModule:
  logit("websocket", "INFO", "Websocket main started")

  asyncCheck pong(server)


  # Bad solution.. !!!
  var httpServer: AsyncHttpServer
  try:
    httpServer = newAsyncHttpServer()
    asyncCheck serve(httpServer, Port(25437), onRequest)

    runForever()

  except IOError:
    logit("websocket", "ERROR", "IOError.. damn")


  close(httpServer)
