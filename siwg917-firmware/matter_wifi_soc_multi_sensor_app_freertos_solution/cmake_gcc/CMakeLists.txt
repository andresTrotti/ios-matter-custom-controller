# Define minimal required version of CMake.
cmake_minimum_required(VERSION "3.25")

# Project definition
project(matter_wifi_soc_multi_sensor_app_freertos_solution)

include(ExternalProject)

ExternalProject_Add(matter_wifi_soc_multi_sensor_app_demo_krasamo
  SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/../matter_wifi_soc_multi_sensor_app_demo_krasamo/cmake_gcc
  BINARY_DIR ${CMAKE_CURRENT_LIST_DIR}/../matter_wifi_soc_multi_sensor_app_demo_krasamo/cmake_gcc/build
  CMAKE_ARGS --preset project
  BUILD_COMMAND ${CMAKE_COMMAND} --build . --config $<CONFIG>
  INSTALL_COMMAND ""
  BUILD_ALWAYS true
  USES_TERMINAL_BUILD 1
  WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/../matter_wifi_soc_multi_sensor_app_demo_krasamo/cmake_gcc
)


set(post_build_command )


add_custom_target(postbuild ALL
    WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/..
    COMMAND ${post_build_command}
)

add_dependencies(postbuild matter_wifi_soc_multi_sensor_app_demo_krasamo)

# BEGIN_SIMPLICITY_STUDIO_METADATA=eJyFUktLw0AQ/ishd7OtgocSFbEeAkkjpgWFwLJupu3a7E7Y2TaK+N8d+9SDeNsZvsfMN/sRV1nxkGd32fRZVtPZOCtlVeazaVZOZFGO7/N4FKc3b7aNNuDJoLuq42EyqOMInMbGuAU3bqu7LKvjm+vapUWF7TowkCJmORq9kWHIMoRuJETf90l/kaBfiPPBYCieirzSS7DqzDgKymlgZWaMHE6UBeqUhh0gR63Czv+HFplWvVCi0QoicbBOQKNnJZ4nilLad7cV1wdUgc26hUeYg+ddgCLTsDi1OunRr7bWSaOCqmNxpI6LMcyNM9/8v/F7OBM6j6+gQ+R4GQZbFQJ42Zu5kYRa2nUb+AWO0EvVdbIBi3LlFSmLnER7WlrMiA8ggscQjKiM7VqjTXivwroxKDaX8jiF+Ndm7gF8QJKHbP6n/J7smIj4FckucPEj8VScPgSX8ecXFVjhmQ===END_SIMPLICITY_STUDIO_METADATA