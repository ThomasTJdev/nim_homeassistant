# Copyright 2018 - Thomas T. Jarløv
from jester import Request

type
  Userrank* = enum
    Normal
    Moderator
    Admin
    Deactivated
    NotLoggedin

type
  Session* = object of RootObj
    loggedIn*: bool
    username*, userpass*, email*: string
    
  TData* = ref object of Session
    req*: jester.Request
    userid*: string         # User ID
    timezone*: string       # User timezone
    rank*: Userrank             # User status (rank)


