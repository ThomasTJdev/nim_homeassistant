
import parsecfg
from os import getAppDir, `/`
from strutils import replace

proc loadConf*(modulename: string): Config =
  ## Load config for the main daemon or a module
  var fn = ""
  when defined(dev):
    if modulename == "":
      # main daemon
      fn = getAppDir() & "/config/nimha_dev.cfg"
    else:
      fn = replace(getAppDir(), "/nimhapkg/mainmodules", "") & "/config/nimha_dev.cfg"
  else:
    fn = "/etc/nimha/nimha.cfg"

  echo("Reading cfg file " & fn)
  loadConfig(fn)

#installpath
const systmp = "/var/run/nimha/tmp"

proc getTmpDir*(modulename = ""): string =
  ## Temporary directory, not persistent across restarts
  when defined(dev):
    replace(getAppDir(), "/nimhapkg/mainmodules", "") / "/tmp"
  else:
    if modulename == "":
      systmp / "nimha"
    else:
      # TODO: check for path traversal?
      systmp / modulename

proc getNimbleCache*(): string =
  ## Get Nimble cache
  when defined(dev):
    replace(getAppDir(), "/nimhapkg/mainmodules", "") / "/nimblecache"
  else:
    #installpath
    "/var/run/nimha/nimblecache"

