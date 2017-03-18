fs = require 'fs'
path = require 'path'
os = require 'os'
logger = require './logger'

# Module for detecting the server executable. It searches for the executable to
# initialize the settings. It inspects a few known location depending on OS.
module.exports = ExeLocator =
  exeSet: () ->
    daemonPath = atom.config.get("haskell-tools.daemon-path")
    return fs.existsSync(daemonPath)

  locateExe: () ->
    if @exeSet() then return
    pathes = []
    switch os.platform()
      when 'win32'
        userName = process.env['USERPROFILE'].split(path.sep)[2];
        pathes = [ "C:\\Users\\" + userName + "\\AppData\\Roaming\\cabal\\bin\\ht-daemon.exe"
                 , "C:\\Users\\" + userName + "\\AppData\\Roaming\\local\\bin\\ht-daemon.exe"
                 ]
      when 'linux', 'darwin', 'openbsd', 'freebsd'
        pathes = [ "~/.cabal/bin/ht-daemon" ]
      else
        logger.error('Unknown OS: ' + os.platform() + '. Select ht-daemon executable manually.')
        atom.notifications.addInfo("Cannot determine OS. Select ht-daemon executable manually.")

    found: false
    for path in pathes
      if fs.existsSync(path)
        found = true
        atom.config.set("haskell-tools.daemon-path", path)

    if !found
      msg = "Cannot automatically find ht-daemon executable. Select ht-daemon " +
            "executable manually in the settings. If ht-daemon is not " +
            "installed user 'cabal install ht-daemon'."
      atom.notifications.addInfo(msg)
