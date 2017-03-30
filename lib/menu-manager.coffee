# Adds the option to enable/disable menu items in Atom
module.exports = MenuManager =
  # Enables a given command in the menu
  enableCommand: (command) ->
    @updateCommand command, atom.menu.template, (elem) => elem.enabled = true
    atom.menu.update()

  # Disables a given command in the menu
  disableCommand: (command) ->
    @updateCommand command, atom.menu.template, (elem) => elem.enabled = false
    atom.menu.update()

  updateCommand: (command, menu, op) ->
    for elem in menu
      if elem.command && elem.command.match RegExp(command)
        op(elem)
      if elem.submenu then @updateCommand(command, elem.submenu, op)
