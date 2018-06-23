# Copyright 2018 - Thomas T. Jarløv

import json


template jn*(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON

  try:
    json[data].getStr()
  except:
    ""

template jnInt*(json: JsonNode, data: string): int =
  ## Avoid error in parsing JSON

  try:
    json[data].getInt()
  except:
    0

template jnFloat*(json: JsonNode, data: string): float =
  ## Avoid error in parsing JSON

  try:
    json[data].getFloat()
  except:
    0

template js*(data: string): JsonNode =
  ## Avoid error in parsing JSON

  try:
    parseJson(data)
  except:
    parseJson("{}")