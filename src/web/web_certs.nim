# Copyright 2018 - Thomas T. Jarløv

import osproc, strutils, db_sqlite, asyncdispatch

import ../mqtt/mqtt_func


proc certExpiraryJson*(serverAddress, port: string) {.async.} =
  ## Excecute openssl s_client and return dates until expire

  let output = execProcess("echo $((($(date --date \"$(date --date \"$(openssl s_client -connect " & serverAddress & ":" & port & " -servername " & serverAddress & " < /dev/null 2>/dev/null | openssl x509 -noout -enddate | sed -n 's/notAfter=//p')\")\" +%s)-$(date --date now +%s))/86400))")

  var res = ""
  if "unable to load" in output:
    res = "{\"handler\": \"response\", \"value\": \"error\"}"
  else:
    res = "{\"handler\": \"action\", \"element\": \"certexpiry\", \"server\": \"" & replace(serverAddress, ".", "") & "\", \"value\": \"" & replace(output, "\n", "") & "\"}"  

  discard mqttSend("webutils", "wss/to", res)
  


proc certExpiraryDays*(serverAddress, port: string): string =
  ## Excecute openssl s_client and return dates until expire

  let output = execProcess("echo $((($(date --date \"$(date --date \"$(openssl s_client -connect " & serverAddress & ":" & port & " -servername " & serverAddress & " < /dev/null 2>/dev/null | openssl x509 -noout -enddate | sed -n 's/notAfter=//p')\")\" +%s)-$(date --date now +%s))/86400))")

  if "unable to load" in output:
    return ""
    
  return output.replace("\n", "")


proc certExpiraryRaw(serverAddress, port: string): string =
  ## Excecute openssl s_client and return certificate info

  let output = execProcess("echo | openssl s_client -connect " & serverAddress & ":" & port & " -servername " & serverAddress & " 2>/dev/null | openssl x509 -noout -dates | grep notAfter | sed -e 's#notAfter=##'")

  return output


proc certExpirary*(serverAddress, port, format: string): string =
  ## Get certificate expiration date in special format

  let cert = certExpiraryRaw(serverAddress, port)
  
  case format
  of "year":
    return cert.substr(16, 19)
  of "month":
    return cert.substr(0, 2)
  of "day":
    return cert.substr(4, 5)
  of "time":
    return cert.substr(7, 14)
  else:
    return cert


proc certExpiraryAll*(db: DbConn) {.async.} =
  ## Get all web urls and check cert

  let allCerts = getAllRows(db, sql"SELECT url, port FROM certificates")

  var json = ""

  for cert in allCerts:
    asyncCheck certExpiraryJson(cert[0], cert[1])
    #sleep(250)

    

proc certDatabase*(db: DbConn) =
  ## Creates Xiaomi tables in database

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


