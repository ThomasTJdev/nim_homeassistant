# Copyright 2019 - Thomas T. Jarløv

import db_sqlite


proc osDatabase*(db: DbConn) =
  ## Creates os tables in database

  # Mail templates
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS os_templates (
    id INTEGER PRIMARY KEY,
    name TEXT,
    command TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: OS templates table could not be created"