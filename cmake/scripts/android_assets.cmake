# KI-Disclaimer: Dieses Skript wurde von einem KI-Agenten (Claude) geschrieben.
# Copies res/ into the assets of the Android package, without the files FLXXX3 never uses
# (it made the APK about 25 MB bigger): translations (the interface is English), the legacy
# skins other than LateNight (the QML library takes some styles from it), the mappings of all
# other controllers and the files for macOS and Linux.
# Call: cmake -DSRC=<res dir> -DDST=<assets dir> -P android_assets.cmake

if(NOT SRC OR NOT DST)
  message(FATAL_ERROR "SRC and DST are needed")
endif()

file(MAKE_DIRECTORY "${DST}")

# Every entry of res/ is copied fresh: files of an earlier, full copy must go, too. (Other
# files in the assets, like the resource bundle of Qt, stay.)
file(GLOB entries RELATIVE "${SRC}" "${SRC}/*")
foreach(entry IN LISTS entries)
  file(REMOVE_RECURSE "${DST}/${entry}")
  if(entry MATCHES "^(translations|osx|linux|Mixxx-Keyboard-Shortcuts\\.pdf|skins|controllers)$")
    continue()
  endif()
  file(COPY "${SRC}/${entry}" DESTINATION "${DST}")
endforeach()

# Skins: only LateNight and the default style sheets.
file(MAKE_DIRECTORY "${DST}/skins")
file(COPY "${SRC}/skins/LateNight" DESTINATION "${DST}/skins")
file(GLOB skinStyles "${SRC}/skins/*.qss")
file(COPY ${skinStyles} DESTINATION "${DST}/skins")

# Controllers: the DDJ-FLX4 and the shared script libraries.
file(MAKE_DIRECTORY "${DST}/controllers")
foreach(name IN ITEMS
    Pioneer-DDJ-FLX4.midi.xml
    Pioneer-DDJ-FLX4-script.js
    common-controller-scripts.js
    lodash.mixxx.js
    midi-components-0.0.js)
  file(COPY "${SRC}/controllers/${name}" DESTINATION "${DST}/controllers")
endforeach()
