package main


import "core:c/libc"
import win32 "core:sys/windows"
import sdl "vendor:sdl2"


user_directory :: proc(allocator:= context.allocator) -> string {
    userprofile := cast(cstring)libc.getenv("USERPROFILE")
    return string(userprofile)
}