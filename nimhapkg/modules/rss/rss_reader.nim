import asyncdispatch
import db_sqlite
import httpclient
import json
import parsexml
import streams
import strutils

import ../../resources/database/database
import ../../resources/mqtt/mqtt_func


var db = conn()
var dbRss = conn("dbRss.db")


proc rssFormatHtml(field, data: string, websocketMqtt: bool): string =
  ## Formats RSS data to HTML

  var html = ""

  if websocketMqtt:
    html.add("\n  <div class=\\\"rss-field rss-" & field & " " & field & "\\\">" & data & "</div>")
  else:
    html.add("\n  <div class=\"rss-field rss-" & field & " " & field & "\">" & data & "</div>")

  return html


proc rssReadUrl*(name, url: string, fields: varargs[string, `$`], skipNth = 0, websocketMqtt = false, createHTML = true): string =
  ## Reads a RSS feed and reads userdefined fields
  ##
  ## Currently only support for xmlElementStart (closed tags: <title>, <pubDate>, etc.)


  when defined(dev):
    echo "RSS feed data:"
    echo " - RSS URL: " & url
    echo " - RSS fields: " & $fields
    echo " - RSS skip: " & $skipNth


  # Connect to RSS fead and get body
  var client = newHttpClient()
  let rss = getContent(client, url)


  # Start parsing feed
  var nn = newStringStream(rss)
  var x: XmlParser
  open(x, nn, "")
  next(x)


  # Defined
  var rssOut = ""
  var skip = 0
  var startTag = false
  var notStart = false
  let startField = fields[0]
  let endField = fields[fields.len() - 1]

  while true:
    x.next()
    try:
      case x.kind
      of xmlElementStart:

        # Loop through fields
        for field in fields:

          if x.elementName == field:
            if field == startField:
              notStart = false
            else:
              notStart = true

            if field == startField and startTag == true and notStart == true:
              startTag = true
              rssOut.add("\n</div>")

            # Check if <div> is needed
            if field == startField and startTag == false:
              startTag = true
              rssOut.add("\n<div>")

            x.next()

            while x.kind == xmlCharData:
              # Skip line
              if skip < skipNth:
                inc(skip)
                x.next()

              # Generate inner HTML
              if x.charData == "" or x.charData.replace(" ", "") == "\"":
                discard
              elif createHTML:
                rssOut.add(rssFormatHtml(field, x.charData, websocketMqtt))
              else:
                rssOut.add(x.charData)

              x.next()

            # End of element
            if x.kind == xmlElementEnd and x.elementName == field:
              # Check if </div> is needed
              if field == endField:
                startTag = false
                rssOut.add("\n</div>")

              continue


      of xmlEof: break
      of xmlError:
        echo(errorMsg(x))
        x.next()
      else: x.next()

    except AssertionError:
      continue

    except:
      echo "Error: Something went wrong"

  if websocketMqtt:
    rssOut = "<div class=\\\"rss-container rss-" & name & "\\\">" & rssOut & "</div>"
  else:
    rssOut = "<div class=\"rss-container rss-" & name & "\">" & rssOut & "</div>"

  when defined(dev):
    echo " - RSS output: " & rssOut

  return rssOut


proc rssReadUrl*(feedid: string, websocketMqtt = false): string =
  ## Reads a RSS feed from data in database

  let rssData = getRow(dbRss, sql"SELECT url, fields, skip, name FROM rss_feeds WHERE id = ?", feedid)

  return rssReadUrl(rssData[3], rssData[0], rssData[1].split(","), parseInt(rssData[2]), websocketMqtt)


proc rssFeetchToWss(feedid: string) {.async.} =
  ## Reads RSS and sends to WSS

  mqttSend("rss", "wss/to", "{\"handler\": \"action\", \"element\": \"rss\", \"action\": \"update\", \"feedid\": \"" & feedid & "\", \"data\": \"" & rssReadUrl(feedid, true).replace("\n", "") & "\"}")


template jn(json: JsonNode, data: string): string =
  ## Avoid error in parsing JSON

  try:
    json[data].getStr()
  except:
    ""

proc rssParseMqtt*(payload: string) {.async.} =

  let js = parseJson(payload)

  if jn(js, "action") == "refresh":
    let feedid = jn(js, "feedid")
    if feedid == "":
      return

    asyncCheck rssFeetchToWss(feedid)



#echo rssReadUrl("https://www.archlinux.org/feeds/packages/", ["title", "pubDate"], 0)