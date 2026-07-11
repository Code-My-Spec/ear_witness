# LibPE

Implementation of the Windows PE executable format for reading and writing PE binaries.

  Most struct member names are taken directly from the windows documentation:
  https://docs.microsoft.com/en-us/windows/win32/debug/pe-format

  This library has been created specifically to archieve the following:

  * Update the PE checksum in `erl.exe` after making changes
  * Insert a Microsoft manifest file after compilation: https://docs.microsoft.com/de-de/windows/win32/sbscs/application-manifests
  * Insert an Executable Icon after compilation

## update_checksum/1

Update the PE image checksum of a PE file.

## update_layout/1

Update the section & certificate layout after a section size has
  been changed