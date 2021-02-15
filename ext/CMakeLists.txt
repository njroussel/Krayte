# Krayte
set(BUILD_SHARED_LIBS ON CACHE BOOL " " FORCE)

# Kr8md
set(KR8MD_INCLUDE_DIR
    ${CMAKE_CURRENT_SOURCE_DIR}/kr8md/include)

set(ChildVariables
    KR8MD_INCLUDE_DIR)


# Krayte
foreach(ChildVariable ${ChildVariables})
    set(${ChildVariable} "${${ChildVariable}}" PARENT_SCOPE)
endforeach()
