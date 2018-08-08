# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
from httpclient import newHttpClient, downloadFile
import db_sqlite
import jester
import json
import logging
import macros
import os
import parsecfg
import strutils
import times
import uri

from osproc import execProcess

import recaptcha
import ../resources/www/google_recaptcha

import ../resources/database/database
import ../resources/database/sql_safe
import ../resources/mail/mail
import ../resources/mqtt/mqtt_func
import ../resources/pushbullet/pushbullet
import ../resources/rss/rss_reader
import ../resources/users/password
import ../resources/users/user_add
import ../resources/users/user_check
import ../resources/utils/parsers
import ../resources/utils/dates

from ../resources/xiaomi/xiaomi_utils import xiaomiUpdateGatewayPassword


setCurrentDir(replace(getAppDir(), "/nimhapkg/mainmodules", ""))


#[ 
      Defining variables
__________________________________________________]#

# Database connection
var db = conn()



# Jester port
settings:
  port = Port(5000)


let dict = loadConfig(replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/config/secret.cfg")
let gMapsApi = dict.getSectionValue("Google","mapsAPI")



#[ 
      User check
__________________________________________________]#


proc init(c: var TData) =
  ## Empty out user session data
  c.userpass      = ""
  c.username      = ""
  c.userid        = ""
  c.timezone      = ""
  c.rank          = NotLoggedin
  c.loggedIn      = false


    

#[ 
      Validation check
__________________________________________________]#
proc loggedIn(c: TData): bool =
  ## Check if user is logged in
  ## by verifying that c.username is more than 0:int
  result = c.username.len > 0




#[ 
      Check if user is signed in
__________________________________________________]#

proc checkLoggedIn(c: var TData) =
  ## Check if user is logged in

  if not c.req.cookies.hasKey("sidnimha"): return
  let sid = c.req.cookies["sidnimha"]
  if execAffectedRows(db, sql("UPDATE session SET lastModified = ? WHERE ip = ? AND key = ?"), $toInt(epochTime()), c.req.ip, sid) > 0:

    c.userid = getValue(db, sql"SELECT userid FROM session WHERE ip = ? AND key = ?", c.req.ip, sid)

    let row = getRow(db, sql"SELECT name, email, status FROM person WHERE id = ?", c.userid)
    c.username  = row[0]
    c.email     = toLowerAscii(row[1])
    c.rank      = parseEnum[Userrank](row[2])
    if c.rank notin [Admin, Moderator, Normal]:
      c.loggedIn = false

    discard tryExec(db, sql"UPDATE person SET lastOnline = ? WHERE id = ?", toInt(epochTime()), c.userid)

  else:
    c.loggedIn = false




#[ 
      User login
__________________________________________________]#

proc login(c: var TData, email, pass: string): tuple[b: bool, s: string] =
  ## User login

  const query = sql"SELECT id, name, password, email, salt, status, secretUrl FROM person WHERE email = ? AND status <> 'Deactivated'"
  if email.len == 0 or pass.len == 0:
    return (false, "Missing password or username")

  for row in fastRows(db, query, toLowerAscii(email)):
    # Disabled at the moment. No need for email confirmation.
    #if row[6] != "":
    #  return (false, "Your account is not activated")

    if parseEnum[Userrank](row[5]) notin [Admin, Moderator, Normal]:
      return (false, "Your account is not active")

    if row[2] == makePassword(pass, row[4], row[2]):
      c.userid   = row[0]
      c.username = row[1]
      c.userpass = row[2]
      c.email    = toLowerAscii(row[3])
      c.rank     = parseEnum[Userrank](row[5])

      let key = makeSessionKey()
      exec(db, sql"INSERT INTO session (ip, key, userid) VALUES (?, ?, ?)", c.req.ip, key, row[0])
      
      return (true, key)

  return (false, "Login failed")



#[ 
      Logout
__________________________________________________]#
proc logout(c: var TData) =
  ## Logout

  const query = sql"DELETE FROM session WHERE ip = ? AND key = ?"
  c.username = ""
  c.userpass = ""
  exec(db, query, c.req.ip, c.req.cookies["sidnimha"])




#[ 
      Check if logged in
__________________________________________________]#
template createTFD() =
  ## Check if logged in and assign data to user

  var c {.inject.}: TData
  new(c)
  init(c)
  c.req = request
  if request.cookies.len > 0:
    checkLoggedIn(c)
  c.loggedIn = loggedIn(c)






#[ 
      HTML pages
__________________________________________________]#

include "../tmpl/dashboard.tmpl"
include "../tmpl/alarm_numpad.tmpl"
include "../tmpl/main.tmpl"
include "../tmpl/alarm.tmpl"
include "../tmpl/cron.tmpl"
include "../tmpl/users.tmpl"
include "../tmpl/mail.tmpl"
include "../tmpl/filestream.tmpl"
include "../tmpl/mqtt.tmpl"
include "../tmpl/certificates.tmpl"
include "../tmpl/owntracks.tmpl"
include "../tmpl/pushbullet.tmpl"
include "../tmpl/rss.tmpl"
include "../tmpl/xiaomi.tmpl"






#[ 
      Cleanup
__________________________________________________]#

proc handler() {.noconv.} =
  quit(1)





#[ 
      Init
__________________________________________________]#

when isMainModule:
  setControlCHook(handler)
  
  let hostIp = execProcess("ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\.){3}[0-9]*' | grep -Eo '([0-9]*\\.){3}[0-9]*' | grep -v '127.0.0.1'")
  echo "\nAccess the webinterface on " & replace(hostIp, "\n", "") & ":5000\n"
    
  #[
  # Save startup time
  exec(db, sql"INSERT INTO mainevents (event, value) VALUES (?, ?)", "start", "main", toInt(epochTime()))

  ]#
  



#[ 
      Webserver
__________________________________________________]#

routes:
  get "/":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genMain(c)

  
  get "/logout":
    createTFD()
    logout(c)
    redirect("/login")


  get "/login":
    createTFD()
    if c.loggedIn and @"errormsg" == "":
      redirect("/login?errormsg=" & encodeUrl("You are already logged in"))

    resp genLogin(c, @"errormsg")


  post "/dologin":
    createTFD()
    when not defined(dev):
      if useCaptcha:
        if not await checkReCaptcha(@"g-recaptcha-response", c.req.ip):
          redirect("/login")
    
    let (loginB, loginS) = login(c, @"email", replace(@"password", " ", ""))
    if loginB:
      setCookie("sidnimha", loginS, daysForward(7))
      redirect("/")
    else:
      redirect("/login?errormsg=" & encodeUrl(loginS))


  get "/certificates":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genCertificates(c)


  get "/certificates/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "addcert":
      exec(db, sql"INSERT INTO certificates (name, url, port) VALUES (?, ?, ?)", @"name", @"url", @"port")

    elif @"action" == "deletecert":
      exec(db, sql"DELETE FROM certificates WHERE id = ?", @"id")

    redirect("/certificates")

  
  get "/xiaomi/devices":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genXiaomiDevices(c)


  get "/xiaomi/devices/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "addsensor":
      let triggerAlarm = if @"triggeralarm" notin ["armAway", "armHome"]: "false" else: @"triggeralarm"

      let valuedata = if @"triggeralarm" == "false": "" else: @"valuedata"

      exec(db, sql"INSERT INTO xiaomi_devices_data (sid, value_name, value_data, action, triggerAlarm) VALUES (?, ?, ?, ?, ?)", @"sid", @"valuename", valuedata, @"handling", triggerAlarm)

    elif @"action" == "deletesensor":
      exec(db, sql"DELETE FROM xiaomi_devices_data WHERE id = ?", @"id")

    elif @"action" == "addaction":
      exec(db, sql"INSERT INTO xiaomi_templates (sid, name, value_name, value_data) VALUES (?, ?, ?, ?)", @"sid", @"name", @"valuename", @"valuedata")

    elif @"action" == "deleteaction":
      exec(db, sql"DELETE FROM xiaomi_templates WHERE id = ?", @"id")

    elif @"action" == "updatedevice":
      exec(db, sql"UPDATE xiaomi_devices SET name = ? WHERE sid = ?", @"name", @"sid")

    elif @"action" == "updatekey":
      exec(db, sql"UPDATE xiaomi_api SET key = ? WHERE sid = ?", @"key", @"sid")
      xiaomiUpdateGatewayPassword()

    redirect("/xiaomi/devices")


  get "/owntracks":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genOwntracks(c)


  get "/owntracks/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "deletedevice":
      exec(db, sql"DELETE FROM owntracks_devices WHERE username = ? AND device_id = ?", @"username", @"deviceid")
      exec(db, sql"DELETE FROM owntracks_history WHERE username = ? AND device_id = ?", @"username", @"deviceid")

    elif @"action" == "clearhistory":
      exec(db, sql"DELETE FROM owntracks_history WHERE username = ? AND device_id = ?", @"username", @"deviceid")

    elif @"action" == "deletewaypoint":
      exec(db, sql"DELETE FROM owntracks_waypoints WHERE id = ?", @"waypointid")

    redirect("/owntracks")


  get "/alarm":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genAlarm(c)


  get "/code":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genAlarmCode(c)


  get "/alarm/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if c.rank != Admin:
      redirect("/alarm")

    if @"action" == "addaction":

      let query = "SELECT name FROM " & @"alarmelement" & "_templates WHERE id = ?"
      let name = getValue(db, sql(query), @"alarmid")

      exec(db, sql"INSERT INTO alarm_actions (alarmstate, action, action_ref, action_name) VALUES (?, ?, ?, ?)", @"alarmstate", @"alarmelement", @"alarmid", name)

    elif @"action" == "deleteaction":
      exec(db, sql"DELETE FROM alarm_actions WHERE id = ?", @"actionid")

    elif @"action" == "updatecountdown":
      exec(db, sql"UPDATE alarm_settings SET value = ? WHERE element = ?", @"countdown", "countdown")

    elif @"action" == "updatecarmtime":
      exec(db, sql"UPDATE alarm_settings SET value = ? WHERE element = ?", @"armtime", "armtime")

    elif @"action" == "adduser":
      # Check if user exists
      let userExists = getValue(db, sql"SELECT id FROM alarm_password WHERE userid = ?", @"userid")

      if userExists == "" and isDigit(@"password"):
        let salt = makeSalt()
        let password = makePassword(@"password", salt)

        discard insertID(db, sql"INSERT INTO alarm_password (userid, password, salt) VALUES (?, ?, ?)", @"userid", password, salt)

    elif @"action" == "deleteuser":
      execSafe(db, sql"DELETE FROM alarm_password WHERE userid = ?", @"userid")

    redirect("/alarm")


  get "/mail":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genMail(c)


  get "/mail/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "testmail":
      asyncCheck sendMailNow("NimHA: Testmail", "A testmail", @"recipient")

    elif @"action" == "updatesettings":
      exec(db, sql"UPDATE mail_settings SET address = ?, port = ?, fromaddress = ?, user = ?, password = ? WHERE id = ?", @"address", @"port", @"from", @"user", @"password", "1")
      
      mailUpdateParameters(db)

    elif @"action" == "addmail":
      exec(db, sql"INSERT INTO mail_templates (name, recipient, subject, body) VALUES (?, ?, ?, ?)", @"name", @"recipient", @"subject", @"body")

    elif @"action" == "deletemail":
      exec(db, sql"DELETE FROM mail_templates WHERE id = ?", @"mailid")

    redirect("/mail")


  get "/pushbullet":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genPushbullet(c)


  get "/pushbullet/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "updateapi":
      pushbulletNewApi(db, @"api")

    elif @"action" == "addpush":
      exec(db, sql"INSERT INTO pushbullet_templates (name, title, body) VALUES (?, ?, ?)", @"name", @"title", @"body")

    elif @"action" == "deletepush":
      exec(db, sql"DELETE FROM pushbullet_templates WHERE id = ?", @"pushid")

    redirect("/pushbullet")


  get "/rss":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genRss(c, @"testfeed")


  get "/rss/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "addfeed":
      let skip = if @"skip" == "" or not isDigit(@"skip"): "0" else: @"skip"
      exec(db, sql"INSERT INTO rss_feeds (url, skip, fields, name) VALUES (?, ?, ?, ?)", @"url", skip, @"fields", @"name")

    elif @"action" == "deletefeed":
      exec(db, sql"DELETE FROM rss_feeds WHERE id = ?", @"feedid")

    elif @"action" == "testfeed":
      let skip = if @"skip" == "" or not isDigit(@"skip"): 0 else: parseInt(@"skip")
      resp genRss(c, rssReadUrl("Test", @"url", [@"fields"], skip))


    redirect("/rss")


  get "/cron":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genCron(c)


  get "/cron/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "addaction":
      let query = "SELECT name FROM " & @"cronelement" & "_templates WHERE id = ?"
      let name = getValue(db, sql(query), @"cronid")

      exec(db, sql"INSERT INTO cron_actions (element, action_name, action_ref, time, active) VALUES (?, ?, ?, ?, ?)", @"cronelement", name, @"cronid", @"time", "true")

    elif @"action" == "deleteaction":
      exec(db, sql"DELETE FROM cron_actions WHERE id = ?", @"cronid")

    redirect("/cron")



  get "/filestream":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genFilestream(c)


  get "/filestream/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "addstream":
      let download = if @"streamdownload" notin ["true", "false"]: "false" else: @"streamdownload"
      let html = if @"streamhtml" notin ["img", "video"]: "img" else: @"streamhtml"
      exec(db, sql"INSERT INTO filestream (name, url, download, html) VALUES (?, ?, ?, ?)", @"streamname", @"streamurl", download, html)

    elif @"action" == "deletestream":
      exec(db, sql"DELETE FROM filestream WHERE id = ?", @"streamid")

    redirect("/filestream")

  get "/filestream/download":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"url".len() == 0:
      resp("")

    let filename = split(@"url", "/")[split(@"url", "/").len()-1]
    var aa = newHttpClient()
    downloadFile(aa, @"url", "tmp/" & filename)
    sendFile("tmp/" & filename)
    

  after "/filestream/download":
    let filename = split(@"url", "/")[split(@"url", "/").len()-1]
    discard tryRemoveFile("tmp/" & filename)


  get "/mqtt":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    resp genMqtt(c)


  get "/mqtt/do":
    createTFD()
    if not c.loggedIn:
      redirect("/login")

    if @"action" == "addmqtt":
      exec(db, sql"INSERT INTO mqtt_templates (name, topic, message) VALUES (?, ?, ?)", @"mqttname", @"mqtttopic", @"mqttmessage")

    elif @"action" == "deletemqtt":
      exec(db, sql"DELETE FROM mqtt_templates WHERE id = ?", @"actionid")

    elif @"action" == "sendtest":
      asyncCheck mqttSendAsync("mqttaction", @"topic", @"message")

    redirect("/mqtt")