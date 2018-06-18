# Copyright 2018 - Thomas T. Jarløv

import osproc, strutils, db_sqlite, asyncdispatch

import ../mqtt/mqtt_func

from times import epochTime


proc certExpiraryDaysTo*(serverAddress, port: string): string =
  ## Return days before a certificate expire

  var sslOut = execProcess("echo $(date --date \"$(openssl s_client -connect " & serverAddress & ":" & port & " -servername " & serverAddress & " < /dev/null 2>/dev/null | openssl x509 -noout -enddate | sed -n 's/notAfter=//p')\" +\"%s\")").replace("\n", "")

  if not isDigit(sslOut):
    return ""

  else:
    return split($((parseFloat(sslOut) - epochTime()) / 86400 ), ".")[0]



proc certExpiraryJson*(serverAddress, port: string) {.async.} =
  ## Excecute openssl s_client and return dates before expiration
  ##
  ## Dot . in serveraddress send in JSON response needs to be
  ## removed due to the use of serveraddress in CSS class

  let daysToExpire = certExpiraryDaysTo(serverAddress, port)

  if not isDigit(daysToExpire):
    discard mqttSend("webutils", "wss/to", "{\"sslOut\": \"action\", \"element\": \"certexpiry\", \"server\": \"" & replace(serverAddress, ".", "") & "\", \"value\": \"error\"}")

  else:
    discard mqttSend("webutils", "wss/to", "{\"handler\": \"action\", \"element\": \"certexpiry\", \"server\": \"" & replace(serverAddress, ".", "") & "\", \"value\": \"" & daysToExpire & "\"}")



proc certExpiraryAll*(db: DbConn) {.async.} =
  ## Get all web urls and check cert

  let allCerts = getAllRows(db, sql"SELECT url, port FROM certificates")

  for cert in allCerts:
    asyncCheck certExpiraryJson(cert[0], cert[1])

    

proc certDatabase*(db: DbConn) =
  ## Creates web certificates tables in database

  # Devices
  if not db.tryExec(sql"""
  CREATE TABLE IF NOT EXISTS certificates (
    id INTEGER PRIMARY KEY,
    name TEXT,
    url TEXT,
    port INTEGER,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""", []):
    echo " - Certificated DB: certificates table already exists"


