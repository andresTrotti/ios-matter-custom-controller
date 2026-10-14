# Define minimal required version of CMake.
cmake_minimum_required(VERSION "3.25")

# Project definition
project(
	matter_wifi_soc_multi_sensor_app_demo_krasamo
	VERSION 1.0
	LANGUAGES C CXX ASM
)

# Include the definition of the slc_matter_wifi_soc_multi_sensor_app_demo_krasamo target,
# which contains the content of the SLC project
include(matter_wifi_soc_multi_sensor_app_demo_krasamo.cmake)

add_executable(matter_wifi_soc_multi_sensor_app_demo_krasamo
    # Add additional sources here
)

target_include_directories(matter_wifi_soc_multi_sensor_app_demo_krasamo PUBLIC
    # Add additional include paths here
)

target_compile_definitions(matter_wifi_soc_multi_sensor_app_demo_krasamo PUBLIC
    # Add additional macros here
)

target_compile_options(matter_wifi_soc_multi_sensor_app_demo_krasamo PUBLIC
    # Set additional compiler flags here
)

target_link_options(matter_wifi_soc_multi_sensor_app_demo_krasamo PUBLIC
    # Set additional linker flags here
)

# Link with the content defined in the SLC project
target_link_libraries(matter_wifi_soc_multi_sensor_app_demo_krasamo PRIVATE
    slc
)

# Include managed project content if available
include(matter_wifi_soc_multi_sensor_app_demo_krasamo_project.cmake OPTIONAL RESULT_VARIABLE managed_project)
if(managed_project)
    message(STATUS "Using managed project content from ${managed_project}")
endif()

# Force the gcc linker command
set_target_properties(matter_wifi_soc_multi_sensor_app_demo_krasamo PROPERTIES LINKER_LANGUAGE C)

# Create .bin, .hex and .s37 artifacts after building the project
add_custom_command(TARGET matter_wifi_soc_multi_sensor_app_demo_krasamo
    POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} ${OBJCOPY_SREC_CMD} "$<TARGET_FILE:matter_wifi_soc_multi_sensor_app_demo_krasamo>" "$<TARGET_FILE_DIR:matter_wifi_soc_multi_sensor_app_demo_krasamo>/$<TARGET_FILE_BASE_NAME:matter_wifi_soc_multi_sensor_app_demo_krasamo>.s37"
    COMMAND ${CMAKE_OBJCOPY} ${OBJCOPY_IHEX_CMD} "$<TARGET_FILE:matter_wifi_soc_multi_sensor_app_demo_krasamo>" "$<TARGET_FILE_DIR:matter_wifi_soc_multi_sensor_app_demo_krasamo>/$<TARGET_FILE_BASE_NAME:matter_wifi_soc_multi_sensor_app_demo_krasamo>.hex"
    COMMAND ${CMAKE_OBJCOPY} ${OBJCOPY_BIN_CMD}  "$<TARGET_FILE:matter_wifi_soc_multi_sensor_app_demo_krasamo>" "$<TARGET_FILE_DIR:matter_wifi_soc_multi_sensor_app_demo_krasamo>/$<TARGET_FILE_BASE_NAME:matter_wifi_soc_multi_sensor_app_demo_krasamo>.bin" 
)

# Run post-build pipeline to perform additional post-processing
if(post_build_command)
add_custom_command(TARGET matter_wifi_soc_multi_sensor_app_demo_krasamo
    POST_BUILD
    WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/..
    COMMAND ${post_build_command}
)
endif()