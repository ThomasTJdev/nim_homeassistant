# Copyright 2018 - Thomas T. Jarløv

import db_sqlite



proc owntracksDatabase*(db: DbConn) =
  ## Creates Xiaomi tables in database

  # Devices
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS owntracks_devices (
    username TEXT PRIMARY KEY,
    device_id TEXT,
    tracker_id TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: Owntracks device table could not be created"

  # Waypoints
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS owntracks_waypoints (
    id INTEGER PRIMARY KEY,
    username TEXT,
    device_id TEXT,
    desc TEXT,
    lat INTEGER,
    lon INTEGER,
    rad INTEGER,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (username) REFERENCES owntracks_devices(username)
  );"""):
    echo "ERROR: Owntracks waypoints table could not be created"

  # History
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS owntracks_history (
    id INTEGER PRIMARY KEY,
    username TEXT,
    device_id TEXT,
    tracker_id TEXT,
    lat INTEGER,
    lon INTEGER,
    conn VARCHAR(10),
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (username) REFERENCES owntracks_devices(username)
  );"""):
    echo "ERROR: Owntracks history table could not be created"