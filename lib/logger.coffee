module.exports = Logger =
  log: (msg) -> if atom.config.get("haskell-tools.debug-mode")
                  console.log msg

  error: (msg) -> console.error msg
