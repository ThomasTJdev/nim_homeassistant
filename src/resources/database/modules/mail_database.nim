# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


proc mailDatabase*(db: DbConn) =
  ## Creates mail tables in database

  # Mail settings
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS mail_settings (
    id INTEGER PRIMARY KEY,
    address TEXT,
    port TEXT,
    fromaddress TEXT,
    user TEXT,
    password TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: Mail settings table could not be created"

  if getAllRows(db, sql"SELECT id FROM mail_settings").len() <= 0:
    exec(db, sql"INSERT INTO mail_settings (address, port, fromaddress, user, password) VALUES (?, ?, ?, ?, ?)", "smtp.com", "537", "mail@mail.com", "mailer", "secret")

  # Mail templates
  if not tryExec(db, sql"""
  CREATE TABLE IF NOT EXISTS mail_templates (
    id INTEGER PRIMARY KEY,
    name TEXT,
    recipient TEXT,
    subject TEXT,
    body TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""):
    echo "ERROR: Mail templates table could not be created"