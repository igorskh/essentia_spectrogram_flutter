cmake_minimum_required(VERSION 3.22.1)
project("EssentiaSpectrogramFlutterPlugin")


# Declare the pre-built .so as an imported library
add_library(libessentia SHARED IMPORTED)


set_target_properties(libessentia PROPERTIES
    IMPORTED_LOCATION
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libessentia.so
)

# Include headers from the .h files
include_directories(${CMAKE_SOURCE_DIR}/include/essentia ${CMAKE_SOURCE_DIR}/include/eigen)

# Build your JNI bridge as a shared library
add_library(
    native-bridge
    SHARED
    native-bridge.cpp
)

find_library(log-lib log)

# Link your bridge against the pre-built lib and Android log
target_link_libraries(
    native-bridge
    libessentia
    ${log-lib}
    android
)