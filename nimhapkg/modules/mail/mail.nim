# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch
import db_sqlite
import smtp
import strutils

import ../../resources/database/database

var db = conn()
var dbMail = conn("dbMail.db")

var smtpAddress    = ""
var smtpPort       = ""
var smtpFrom       = ""
var smtpUser       = ""
var smtpPassword   = ""


proc sendMailNow*(subject, message, recipient: string) {.async.} =
  ## Send the email through smtp

  when defined(dev):
    echo "Dev: Mail start"

  #when defined(dev) and not defined(devemailon):
  #  echo "Dev is true, email is not send"
  #  return
  const otherHeaders = @[("Content-Type", "text/html; charset=\"UTF-8\"")]

  var client = newAsyncSmtp(useSsl = true, debug = false)
  await client.connect(smtpAddress, Port(parseInt(smtpPort)))

  await client.auth(smtpUser, smtpPassword)

  let from_addr = smtpFrom
  let toList = @[recipient]

  var headers = otherHeaders
  headers.add(("From", from_addr))

  let encoded = createMessage(subject, message, toList, @[], headers)

  try:
    echo "sin"
    await client.sendMail(from_addr, toList, $encoded)

  except:
    echo "Error in sending mail: " & recipient

  when defined(dev):
    echo "Email send"


proc sendMailDb*(mailID: string) =
  ## Get data from mail template and send
  ## Uses Sync Socket

  when defined(dev):
    echo "Dev: Mail start"

  let mail = getRow(dbMail, sql"SELECT recipient, subject, body FROM mail_templates WHERE id = ?", mailID)

  let recipient = mail[0]
  let subject   = mail[1]
  let message   = mail[2]

  const otherHeaders = @[("Content-Type", "text/html; charset=\"UTF-8\"")]

  var client = newSmtp(useSsl = true, debug = false)
  client.connect(smtpAddress, Port(parseInt(smtpPort)))
  client.auth(smtpUser, smtpPassword)

  let from_addr = smtpFrom
  let toList = @[recipient]

  var headers = otherHeaders
  headers.add(("From", from_addr))

  let encoded = createMessage(subject, message, toList, @[], headers)

  try:
    client.sendMail(from_addr, toList, $encoded)

  except:
    echo "Error in sending mail: " & recipient

  when defined(dev):
    echo "Email send"


proc mailUpdateParameters*() =
  ## Update mail settings in variables

  let mailSettings = getRow(dbMail, sql"SELECT address, port, fromaddress, user, password FROM mail_settings WHERE id = ?", "1")

  smtpAddress    = mailSettings[0]
  smtpPort       = mailSettings[1]
  smtpFrom       = mailSettings[2]
  smtpUser       = mailSettings[3]
  smtpPassword   = mailSettings[4]


mailUpdateParameters()