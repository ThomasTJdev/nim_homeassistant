# Copyright 2018 - Thomas T. Jarløv

import db_sqlite


proc getValueSafe*(db: DbConn, query: SqlQuery, args: varargs[string, `$`]): string =
  when not defined(dev) or defined(sqlsafe):
    try:
      return getValue(db, query, args)
    except DbError:
      echo(getCurrentExceptionMsg())
      return ""

  when defined(dev):
    return getValue(db, query, args)


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