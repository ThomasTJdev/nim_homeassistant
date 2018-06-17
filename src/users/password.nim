# Copyright 2018 - Thomas T. Jarløv

import md5, bcrypt
import math, random, os
randomize()


var urandom: File
let useUrandom = urandom.open("/dev/urandom")


proc makeSalt*(): string =
  ## Generate random salt. Uses cryptographically secure /dev/urandom
  ## on platforms where it is available, and Nim's random module in other cases.
  result = ""
  if useUrandom:
    var randomBytes: array[0..127, char]
    discard urandom.readBuffer(addr(randomBytes), 128)
    for ch in randomBytes:
      if ord(ch) in {32..126}:
        result.add(ch)
  else:
    for i in 0..127:
      result.add(chr(rand(94) + 32)) # Generate numbers from 32 to 94 + 32 = 126


proc makeSessionKey*(): string =
  ## Creates a random key to be used to authorize a session.
  let random = makeSalt()
  return bcrypt.hash(random, genSalt(8))


proc makePassword*(password, salt: string, comparingTo = ""): string =
  ## Creates an MD5 hash by combining password and salt
  let bcryptSalt = if comparingTo != "": comparingTo else: genSalt(8)
  result = hash(getMD5(salt & getMD5(password)), bcryptSalt)