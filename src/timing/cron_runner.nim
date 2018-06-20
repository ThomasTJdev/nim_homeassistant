# Copyright 2018 - Thomas T. Jarløv


import parsecfg, db_sqlite, strutils, asyncdispatch, json, times
#import mqtt
from os import sleep

import ../database/database
import ../database/sql_safe
import ../mail/mail
#import ../mqtt/mqtt_func
import ../pushbullet/pushbullet
import ../xiaomi/xiaomi


var db = conn()


template jn(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON

  try:
    json[data].getStr()
  except:
    ""


#[
type
  Cronjob = ref object
    element: string
    jobid: string
    time: string
    active: bool

  Cron = ref object
    cronjobs: seq[Cronjob]


var cron = Cron(cronjobs: @[])


proc newCronjob(element, jobid, time, active: string): Cronjob =
  ## Generate new cronjob

  return Cronjob(
    element: element,
    jobid: jobid,
    time: time,
    active: parseBool(active)
  )


proc cronUpdateJobs() =
  ## Update the cronjob container

  let cronActions = getAllRows(db, sql"SELECT element, action_ref, time, active FROM cron_actions")

  var newCronjobs: seq[Cronjob] = @[]
  for row in cronActions:
    if row[3] == "false":
      continue

    newCronjobs.add(newCronjob(row[0], row[1], row[2], row[3]))

  cron.cronjobs = newCronjobs


proc cronJobRun() {.async.} =
  ## Run the cron jobs

  let cronTime = format(local(now()), "HH:mm")
  echo format(local(now()), "HH:mm:ss")
  if cron.cronjobs.len() > 0:
    sleep(5000)
    var newCronjobs: seq[Cronjob] = @[]
    for cronitem in cron.cronjobs:
      if not cronitem.active:
        continue
      
      # Add job to seq
      newCronjobs.add(cronitem)

      # Check time. If hour and minut fits (24H) then go
      if cronTime != cronitem.time:
        continue
      
      cronitem.active = false

      case cronitem.element
      of "pushbullet":
        echo "push"
        asyncCheck pushbulletSendDb(db, cronitem.jobid)

      of "mail":
        asyncCheck sendMailDb(db, cronitem.jobid)

      of "xiaomi":
        asyncCheck xiaomiWriteTemplate(db, cronitem.jobid)

      else:
        discard
    
    # Update seq - exclude non active
    cron.cronjobs = newCronjobs
]#


proc cronJobRun(time: string) =
  ## Run the cron jobs

  let cronActions = getAllRowsSafe(db, sql"SELECT element, action_ref FROM cron_actions WHERE active = ? AND time = ?", "true", time)

  if cronActions.len() == 0:
    return

  for row in cronActions:

    case row[0]
    of "pushbullet":
      echo "push"
      asyncCheck pushbulletSendDb(db, row[1])

    of "mail":
      asyncCheck sendMailDb(db, row[1])

    of "xiaomi":
      asyncCheck xiaomiWriteTemplate(db, row[1])

    else:
      discard



proc cronJob() =
  ## Run the main cron job
  ## 
  ## Check every minute if an action is required
  ##
  ## Currently using sleep - should be sleepAsync?
  ## but it messes up the RPi CPU

  echo "Cron main started"


  while true:

    cronJobRun(format(local(now()), "HH:mm"))

    # Wait before next cron check
    # Get current seconds, subtract from 60 to
    # get next starting minute and sleep. This
    # will accept that we are blocking using sleep
    
    let sleepTime = 60 - parseInt(format(local(now()), "ss"))

    sleep(sleepTime * 1000)



proc cronDatabase*(db: DbConn) =
  ## Creates cron tables in database

  # Cron actions
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS cron_actions (
    id INTEGER PRIMARY KEY,
    element TEXT,
    action_name TEXT,
    action_ref TEXT,
    time TEXT,
    active TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")



when isMainModule:
  cronDatabase(db)
  sleep(5000)
  cronJob()
  runForever()