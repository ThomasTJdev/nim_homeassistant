# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


proc mqttDatabase*(db: DbConn) =
  ## Creates cron tables in database

  # Cron actions
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS mqtt_templates (
    id INTEGER PRIMARY KEY,
    name TEXT,
    topic TEXT,
    message TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")
