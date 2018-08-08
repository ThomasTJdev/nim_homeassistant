# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


proc filestreamDatabase*(db: DbConn) =
  ## Creates cron tables in database

  # Cron actions
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS filestream (
    id INTEGER PRIMARY KEY,
    name TEXT,
    url TEXT,
    download TEXT,
    html TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")
