# Bundlex.Doxygen

Module responsible for generating doxygen documentation for Bundlex projects.

## doxygen/1

Prepares struct with all necessary filepaths for the native documentation

## generate_doxyfile/1

Generates doxyfile in the c_src/project directory for Bundlex project.

## generate_doxygen_documentation/1

Generates html doxygen documentation for the Bundlex project. Doxyfile must be generated before.

## generate_hex_page/1

Generates page for the Bundlex project in the pages/doxygen directory.
Page must be manually added to the docs extras in the mix.exs.
Page contains only link to the doxygen html documentation.