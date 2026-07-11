# LibPE.ResourceTable

Parses windows resource tables

  By convention these are always three levels:

    Type > Name > Language

## set_resource/5

Allows updating a resources. At the moment this call is destructive as it does
  not allows defining more than one name or language per resource entry.
  Each defined resource entry set with `set_resource` will have it's PE name
  set to `1` and it's language to the provided language code by default `1033`

  Example:

  > LibPE.ResourceTable.set_resource(table, "RT_MANIFEST", manifest)

  Known resources types are:

  ```
    {"RT_ACCELERATOR", 9, "Accelerator table."},
    {"RT_ANICURSOR", 21, "Animated cursor."},
    {"RT_ANIICON", 22, "Animated icon."},
    {"RT_BITMAP", 2, "Bitmap resource."},
    {"RT_CURSOR", 1, "Hardware-dependent cursor resource."},
    {"RT_DIALOG", 5, "Dialog box."},
    {"RT_DLGINCLUDE", 17,
     "Allows a resource editing tool to associate a string with an .rc file. Typically, the string is the name of the header file that provides symbolic names. The resource compiler parses the string but otherwise ignores the value. For example,"},
    {"RT_FONT", 8, "Font resource."},
    {"RT_FONTDIR", 7, "Font directory resource."},
    {"RT_GROUP_CURSOR", 12, "Hardware-independent cursor resource."},
    {"RT_GROUP_ICON", 14, "Hardware-independent icon resource."},
    {"RT_HTML", 23, "HTML resource."},
    {"RT_ICON", 3, "Hardware-dependent icon resource."},
    {"RT_MANIFEST", 24, "Side-by-Side Assembly Manifest."},
    {"RT_MENU", 4, "Menu resource."},
    {"RT_MESSAGETABLE", 11, "Message-table entry."},
    {"RT_PLUGPLAY", 19, "Plug and Play resource."},
    {"RT_RCDATA", 10, "Application-defined resource (raw data)."},
    {"RT_STRING", 6, "String-table entry."},
    {"RT_VERSION", 16, "Version resource."},
    {"RT_VXD", 20, "VXD."}
  ```