# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


proc rssDatabase*(db: DbConn) =
  ## Creates RSS tables in database

  # RSS feeds
  exec(db, sql"""
  CREATE TABLE IF NOT EXISTS rss_feeds (
    id INTEGER PRIMARY KEY,
    url TEXT,
    skip INTEGER,
    fields TEXT,
    name TEXT,
    creation timestamp NOT NULL default (STRFTIME('%s', 'now'))
  );""")
  