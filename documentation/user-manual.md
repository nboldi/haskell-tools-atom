# Installation guide

 1. You can install an Atom package by selecting Settings/Install
 1. Search for `haskell-tools` (that is the name of the Atom package)

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

# Settings

TODO
