# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


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
