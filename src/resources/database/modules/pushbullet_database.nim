# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


proc pushbulletDatabase*(db: DbConn) =
  ## Creates pushbullet tables in database

  # Pushbullet settings
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS pushbullet_settings (
    id INTEGER PRIMARY KEY,
    api TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")
  if getAllRows(db, sql"SELECT id FROM pushbullet_settings").len() <= 0:
    exec(db, sql"INSERT INTO pushbullet_settings (api) VALUES (?)", "")

  # Pushbullet templates
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS pushbullet_templates (
    id INTEGER PRIMARY KEY,
    name TEXT,
    title TEXT,
    body TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")