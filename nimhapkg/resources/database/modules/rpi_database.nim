# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


proc rpiDatabase*(db: DbConn) =
  ## Creates mail tables in database

  # Raspberry Pi templates
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS rpi_templates (
    id INTEGER PRIMARY KEY,
    name TEXT,
    pin TEXT,
    pinMode TEXT,
    pinPull TEXT,
    digitalAction TEXT,
    analogAction TEXT,
    value TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: Mail templates table could not be created"