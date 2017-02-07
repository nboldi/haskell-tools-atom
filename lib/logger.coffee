
# Controls debug logging. Only logs info messages if the plugin is configured
# to debug mode. Always log errors.
module.exports = Logger =
  log: (msg) -> if atom.config.get("haskell-tools.debug-mode")
                  console.log msg

  error: (msg) -> console.error msg
