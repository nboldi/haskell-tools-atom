fs = require 'fs'
path = require 'path'
os = require 'os'


module.exports = ExeLocator =
  locateExe: () ->
    daemonPath = atom.config.get("haskell-tools.daemon-path")
    if fs.existsSync(daemonPath)
      return

    if /win/.test os.platform()
      userName = process.env['USERPROFILE'].split(path.sep)[2];
      pathes = [ "C:\\Users\\" + userName + "\\AppData\\Roaming\\cabal\\bin\\ht-daemon.exe"
               , "C:\\Users\\" + userName + "\\AppData\\Roaming\\local\\bin\\ht-daemon.exe"
               ]
    else if /linux/.test os.platform()
      pathes = [ "~/.cabal/bin/ht-daemon" ]
    else atom.notifications.addInfo("Cannot determine OS. Select ht-daemon executable manually.")

    found: false
    for path in pathes
      if fs.existsSync(path)
        found = true
        atom.config.set("haskell-tools.daemon-path", path)

    if !found
      atom.notifications.addInfo("Cannot automatically find ht-daemon executable. Select ht-daemon executable manually."
                                   + " If ht-daemon is not installed user 'cabal install ht-daemon'.")

# walk: (dir, done) ->
#   results: []
#   fs.readdir dir, (err, list) =>
#     if (err)
#       done(err)
#     else
#       i = 0
#       next: () ->
#         file = list[i++];
#         if (!file)
#           done(null, results)
#         else
#           file = dir + '/' + file
#           fs.stat file, (err, stat) =>
#             if (stat && stat.isDirectory())
#               walk file, (err, res) =>
#                 results = results.concat(res)
#                 next()
#             else
#               results.push(file)
#               next()
