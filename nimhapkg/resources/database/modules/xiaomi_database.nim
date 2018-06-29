# Copyright 2018 - Thomas T. Jarløv

import db_sqlite



proc xiaomiDatabase*(db: DbConn) =
  ## Creates Xiaomi tables in database

  # Devices
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS xiaomi_devices (
    sid TEXT PRIMARY KEY,
    name TEXT,
    model TEXT,
    short_id TEXT,
    token TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: Xiaomi device table could not be created"

  # Gateway API
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS xiaomi_api (
    sid TEXT PRIMARY KEY,
    key TEXT,
    token TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (sid) REFERENCES xiaomi_devices(sid)
  );"""):
    echo "ERROR: Xiaomi api table could not be created"

  # Sensors ( to be renamed )
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS xiaomi_devices_data (
    id INTEGER PRIMARY KEY,
    sid TEXT,
    value_name TEXT,
    value_data TEXT,
    action TEXT,
    triggerAlarm TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (sid) REFERENCES xiaomi_devices(sid)
  );"""):
    echo "ERROR: Xiaomi device data table could not be created"

  # Actions
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS xiaomi_templates (
    id INTEGER PRIMARY KEY,
    sid TEXT,
    name TEXT,
    value_name TEXT,
    value_data TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (sid) REFERENCES xiaomi_devices(sid)
  );"""):
    echo "ERROR: Xiaomi templates table could not be created"

  # History
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS xiaomi_history (
    id INTEGER PRIMARY KEY,
    sid TEXT,
    cmd TEXT,
    token TEXT,
    data TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (sid) REFERENCES xiaomi_devices(sid)
  );"""):
    echo "ERROR: Xiaomi history table could not be created"

