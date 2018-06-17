# Copyright 2018 - Thomas T. Jarløv

import os, strutils, db_sqlite


import ../users/password


proc createAdminUser*(db: DbConn, args: seq[string]) = 
  ## Create new admin user
  ## Input is done through stdin
  
  echo("User: Checking if any Admin exists in DB")
  let anyAdmin = getAllRows(db, sql"SELECT id FROM person WHERE status = ?", "Admin")
  
  if anyAdmin.len() < 1:
    echo("User: No Admin exists. Create it!")
    
    var iName = ""
    var iEmail = ""
    var iPwd = ""

    for arg in args:
      if arg.substr(0, 2) == "-u:":
        iName = arg.substr(3, arg.len())
      elif arg.substr(0, 2) == "-p:":
        iPwd = arg.substr(3, arg.len())
      elif arg.substr(0, 2) == "-e:":
        iEmail = arg.substr(3, arg.len())

    if iName == "" or iPwd == "" or iEmail == "":
      echo("User: Missing either name, password or email to create the admin user")

    let salt = makeSalt()
    let password = makePassword(iPwd, salt)

    discard insertID(db, sql"INSERT INTO person (name, email, password, salt, status) VALUES (?, ?, ?, ?, ?)", $iName, $iEmail, password, salt, "Admin")

    echo("User: Admin added! Moving on..")
  else:
    echo("User: Admin user already exists. Skipping it.")