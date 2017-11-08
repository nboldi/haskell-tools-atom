# Installation guide

 1. You can install an Atom package by selecting Settings/Install
 1. Search for `haskell-tools` (that is the name of the Atom package)
 1. Go to the package settings
 1. If the daemon-path setting is not filled, input the absolute path of the `ht-daemon` executable you want to use for refactoring. If you haven't installed it, check out the [installation guide](https://github.com/haskell-tools/haskell-tools/blob/master/documentation/installation.md) for Haskell tools.

# Your first refactoring

 1. Start Atom
 1. Create a new folder for the haskell package. Create a new Try.hs file in it, with the content

  ```
   module Try where
   x = ()
   y = x
  ```
 1. If the tree view is not visible, then show it with View/Toggle Tree View.
 1. Right click on the Tree View, click Add Project Folder
 1. Select the folder you created above
 1. Right click on the new Project Folder in the Tree View, click Toggle Haskell-tools Refactoring. The package is now added to Haskell-tools.
 1. Start the Haskell-tools server with Haskell/Start Haskell-tools Server
 1. Now select `x` in Try.hs, click Haskell/Refactor/Rename Definition
 1. Type a new name (`xx`) for the definition.
 1. Now `x` had been renamed to `xx` at both places.

# Features

 - [Core refactorings](https://github.com/haskell-tools/haskell-tools/blob/master/documentation/refactorings.md) are available in the plugin.
 - In the tree view context menu, you can select directories that you want to load into the engine. A package that is loaded will be marked with the  ![sync](octicons_sync.png) icon. You can remove a package from the engine in the same context menu. If you don't want to use the tree view, you can set the refactored packages in the settings.
 - A package can be a simple folder with haskell sources inside, or a cabal package with a `.cabal` file. Cabal sandboxes and stack projects are supported.
 - You can undo refactorings by pressing `Alt+Shift+Z` or selecting `Haskell/Undo last refactoring` from the menu. This reverts all changes from the last refactoring (even in files not opened). However, if you manually change the source after the refactoring, it cannot be used.
 - `Haskell/Check Haskell Tools server` can be used to check if the server is running.
 - The [Haskell-tools refactorings](https://github.com/haskell-tools/haskell-tools/blob/master/documentation/refactorings.md) are available. The default keybindings are:
   - `Alt+Shift+` `R` for **R**ename definition, `B` for Extract **B**inding, `I` for **I**nline binding, `S` for generate type **S**ignature, `O` for **O**rganize Imports, `E` for Generate **E**xports
 - The status bar informs you about the modules being loaeded and the current status of the server.
 - You can access the settings of the plugin below the Haskell menu.
 
For batch trasformations, invoke the [command line interface](https://github.com/haskell-tools/haskell-tools/blob/master/documentation/ht-refact.md) of Haskell-tools.

See the [limitations](https://github.com/haskell-tools/haskell-tools/blob/master/documentation/limitations.md) on projects and modules.
