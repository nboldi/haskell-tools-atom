fs = require 'fs'
path = require 'path'
os = require 'os'
logger = require './logger'

# Module for detecting the server executable. It searches for the executable to
# initialize the settings. It inspects a few known location depending on OS.
module.exports = ExeLocator =
  locateExes: () ->
    if not fs.existsSync(atom.config.get "haskell-tools.daemon-path")
      atom.config.set "haskell-tools.daemon-path", @locateExe "ht-daemon"
    if not fs.existsSync(atom.config.get "haskell-tools.watch-path")
      atom.config.set "haskell-tools.watch-path", @locateExe "hfswatch"

  locateExe: (exeName) ->
    pathes = []
    switch os.platform()
      when 'win32'
        userFolder = process.env['USERPROFILE']
        pathes = [ userFolder + "\\AppData\\Roaming\\cabal\\bin\\" + exeName + ".exe"
                 , userFolder + "\\AppData\\Roaming\\local\\bin\\" + exeName + ".exe"
                 ]
      when 'linux', 'darwin', 'openbsd', 'freebsd'
        userFolder = process.env['USER']
        pathes = [ "/home/" + userFolder + "/.local/bin/" + exeName
                 , "/home/" + userFolder + "/.cabal/bin/" + exeName
                 ]
      else
        logger.error('Unknown OS: ' + os.platform() + '. Select ' + exeName + ' executable manually.')
        atom.notifications.addInfo("Cannot determine OS. Select " + exeName + " executable manually.")

    found: false
    for path in pathes
      if fs.existsSync(path)
        return path

    msg = "Cannot automatically find " + exeName + " executable. Select " + exeName +
          " executable manually in the settings. If " + exeName + " is not " +
          "installed follow the installation instructions."
    atom.notifications.addInfo(msg)
    return ""
