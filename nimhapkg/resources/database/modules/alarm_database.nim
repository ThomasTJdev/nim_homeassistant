# Copyright 2018 - Thomas T. Jarløv

import db_sqlite

proc alarmDatabase*(db: DbConn) =
  ## Creates alarm tables in database

  # Alarm
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS alarm (
    id INTEGER PRIMARY KEY,
    status TEXT,
    modified timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: Alarm table could not be created"

  if getAllRows(db, sql"SELECT id FROM alarm").len() <= 0:
    exec(db, sql"INSERT INTO alarm (status) VALUES (?)", "disarmed")

  # Alarm history
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS alarm_history (
    id INTEGER PRIMARY KEY,
    userid INTEGER,
    status TEXT,
    trigger TEXT,
    device TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (userid) REFERENCES person(id)
  );"""):
    echo "ERROR: Alarm history table could not be created"

  # Alarm settings
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS alarm_settings (
    id INTEGER PRIMARY KEY,
    element TEXT,
    value TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: Alarm settings table could not be created"

  if getAllRows(db, sql"SELECT id FROM alarm_settings").len() <= 0:
    exec(db, sql"INSERT INTO alarm_settings (element, value) VALUES (?, ?)", "countdown", "20")
    exec(db, sql"INSERT INTO alarm_settings (element, value) VALUES (?, ?)", "armtime", "20")

  # Alarm password
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS alarm_password (
    id INTEGER PRIMARY KEY,
    userid INTEGER,
    name VARCHAR(300),
    password VARCHAR(300) NOT NULL,
    salt VARBIN(128) NOT NULL,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (userid) REFERENCES person(id)
  );"""):
    echo "ERROR: Alarm password table could not be created"

  # Alarm actions
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS alarm_actions (
    id INTEGER PRIMARY KEY,
    alarmstate TEXT,
    action TEXT,
    action_name TEXT,
    action_ref TEXT,
    parameter1 TEXT,
    parameter2 TEXT,
    parameter3 TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: Alarm actions table could not be created"
