# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


proc mjpegstreamDatabase*(db: DbConn) =
  ## Creates cron tables in database

  # Cron actions
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS mjpegstream (
    id INTEGER PRIMARY KEY,
    name TEXT,
    url TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")
