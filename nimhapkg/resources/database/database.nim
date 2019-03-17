# Copyright 2018 - Thomas T. Jarløv

import parseCfg, db_sqlite, os, strutils
import ../../resources/utils/common

let dict = loadConf("database")
const default_db_dir = "/var/lib/nimha/db"


let db_user = dict.getSectionValue("Database","user")
let db_pass = dict.getSectionValue("Database","pass")
let db_name = dict.getSectionValue("Database","name")

proc generateDB*(db: DbConn) =

  const
    TPassword = "VARCHAR(32)"

  # Person
  if not db.tryExec(sql("""
  CREATE TABLE IF NOT EXISTS person(
    id INTEGER PRIMARY KEY,
    name VARCHAR(60) NOT NULL,
    password VARCHAR(300) NOT NULL,
    email VARCHAR(60) NOT NULL,
    salt VARBIN(128) NOT NULL,
    status VARCHAR(30) NOT NULL,
    timezone VARCHAR(100),
    secretUrl VARCHAR(250),
    creation timestamp NOT NULL default (STRFTIME('%s', 'now')),
    modified timestamp NOT NULL default (STRFTIME('%s', 'now')),
    lastOnline timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );"""), []):
    echo " - Database: person table already exists"

  # Session
  if not db.tryExec(sql("""
  CREATE TABLE IF NOT EXISTS session(
    id INTEGER PRIMARY KEY,
    ip inet NOT NULL,
    key VARCHAR(32) NOT NULL,
    userid INTEGER NOT NULL,
    lastModified timestamp NOT NULL default (STRFTIME('%s', 'now')),
    FOREIGN KEY (userid) REFERENCES person(id)
  );""" % [TPassword]), []):
    echo " - Database: session table already exists"

  # Main program events
  if not db.tryExec(sql"""
  CREATE TABLE IF NOT EXISTS mainevents(
    id INTEGER PRIMARY KEY,
    event TEXT,
    element TEXT,
    value TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""", []):
    echo " - Database: mainevents table already exists"

  # History
  if not db.tryExec(sql"""
  CREATE TABLE IF NOT EXISTS history (
    id INTEGER PRIMARY KEY,
    element TEXT,
    identifier TEXT,
    error TEXT,
    value TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""", []):
    echo " - Database: history table already exists"

  # Set WAL - https://www.sqlite.org/wal.html
  exec(db, sql"PRAGMA journal_mode=WAL;")

proc setupDbBasedir(): string =
  ## Create database base directory if needed
  result =
    when defined(dev):
      let db_folder = dict.getSectionValue("Database","folder")
      replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/" & db_folder
    else:
      default_db_dir

  discard existsOrCreateDir(result)

proc conn*(dbName="nimha.db"): DbConn =
  ## Connect to the Database, creating dirs and files as needed.
  let db_dir = setupDbBasedir()
  let db_fn = db_dir / dbName
  echo "Opening " & db_fn
  let dbexists = fileExists(db_fn)
  try:
    var db = open(connection=db_fn, user=db_user, password=db_pass, database=db_name)

    if not dbexists:
      echo "Creating tables in " & db_fn
      generateDB(db)

    return db

  except:
    echo "ERROR: Connection to DB could not be established"
    quit()
