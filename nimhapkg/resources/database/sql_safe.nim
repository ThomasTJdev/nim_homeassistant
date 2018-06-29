# Copyright 2018 - Thomas T. Jarløv

import db_sqlite, random

from os import sleep


randomize()


proc getValueSafe*(db: DbConn, query: SqlQuery, args: varargs[string, `$`]): string =
  try:
    return getValue(db, query, args)
  except DbError:
    echo(getCurrentExceptionMsg())
    return ""


proc getValueSafeRetryHelper*(db: DbConn, query: SqlQuery, args: varargs[string, `$`]): string =
  try:
    return getValue(db, query, args)
  except DbError:
    echo(getCurrentExceptionMsg())
    return "ERROR"


proc getValueSafeRetry*(db: DbConn, query: SqlQuery, args: varargs[string, `$`]): string =
  var counter = 0
  var loop = true
  while counter != 3 and loop:
    let res = getValueSafeRetryHelper(db, query, args)
    if res != "ERROR":
      loop = false
      return res
    else:
      inc(counter)
      sleep(rand(50))


proc getAllRowsSafe*(db: DbConn, query: SqlQuery, args: varargs[string, `$`]): seq[Row] =
  when not defined(dev) or defined(sqlsafe):
    try:
      return getAllRows(db, query, args)
    except DbError:
      echo(getCurrentExceptionMsg())
      return @[]

  when defined(dev):
    return getAllRows(db, query, args)


proc getRowSafe*(db: DbConn, query: SqlQuery, args: varargs[string, `$`]): Row =
  when not defined(dev) or defined(sqlsafe):
    try:
      return getRow(db, query, args)
    except DbError:
      echo(getCurrentExceptionMsg())
      return @[]

  when defined(dev):
    return getRow(db, query, args)


proc execSafe*(db: DbConn; query: SqlQuery; args: varargs[string, `$`]) =
  when not defined(dev) or defined(sqlsafe):
    try:
      exec(db, query, args)
    except DbError:
      echo(getCurrentExceptionMsg())
      discard

  when defined(dev):
    exec(db, query, args)


proc tryExecSafe*(db: DbConn; query: SqlQuery; args: varargs[string, `$`]): bool =
  when not defined(dev) or defined(sqlsafe):
    try:
      return tryExec(db, query, args)
    except DbError:
      echo(getCurrentExceptionMsg())
      return false

  when defined(dev):
    return tryExec(db, query, args)


proc tryInsertIDSafe*(db: DbConn; query: SqlQuery; args: varargs[string, `$`]): int64 =
  when not defined(dev) or defined(sqlsafe):
    try:
      return tryInsertID(db, query, args)
    except DbError:
      echo(getCurrentExceptionMsg())
      discard

  when defined(dev):
    return tryInsertID(db, query, args)