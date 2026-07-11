# Mix.Tasks.Pe.Update

SYNTAX: mix pe.update (options) <filename>

  pe.update updates the PE-checksum of the given pe file and
  additionally can add resources to it if needed.

  Options are:

      -h | -help                        This help
      --set-subsystem <subsystemcode>   Update the PE files subsytem type
      --set-icon <filename>             Embeds a given application icon
      --get-icon <filename>             Extracts an embedded icon and stores it to the filename
      --set-manifest <filename>         Embeds a given side-by-side manifest
      --set-info <info_type> <value>    Embeds the given version information
      --set-resource <type> <filename>  Embeds any resources type
      --del-resource <type>             Remove any resources type

  Known info types are:

    "Comments", "CompanyName", "FileDescription", "FileVersion", "InternalName",
    "LegalCopyright", "LegalTrademarks", "OriginalFilename", "PrivateBuild",
    "ProductName", "ProductVersion", "SpecialBuild"

  Known resources types are:

    "RT_ACCELERATOR", "RT_ANICURSOR", "RT_ANIICON", "RT_BITMAP", "RT_CURSOR",
    "RT_DIALOG", "RT_DLGINCLUDE", "RT_FONT", "RT_FONTDIR", "RT_GROUP_CURSOR",
    "RT_GROUP_ICON", "RT_HTML", "RT_ICON", "RT_MANIFEST", "RT_MENU",
    "RT_MESSAGETABLE", "RT_PLUGPLAY", "RT_RCDATA", "RT_STRING", "RT_VERSION",
    "RT_VXD"