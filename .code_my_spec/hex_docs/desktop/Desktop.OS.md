# Desktop.OS

The OS module provides shortcuts and helper functions
  to access OS specific information.

  Most significant one should use OS.type() to differentiate
  between the currently supported environments:
  - Android
  - IOS
  - MacOS
  - Windows
  - Linux

## home/0

Returns the users home directory

## path_expand/1

This is a Path.expand variant that normalizes the drive letter
on windows

## launch_default_browser/1

Replacement for the :wx_misc.launchDefaultBrowser function