package main


import dd "dude/dude/core"
import "core:math"


Rect :: dd.Rect

rect_padding :: proc(r: Rect, left, right, top, bottom: f32) -> Rect {
    assert(left+right < r.w && top+bottom < r.h, "Invalid rect operation")
    return {r.x+left, r.y+top, r.w-right-left, r.h-top-bottom}
}

/*
                width
*-------------*---------*
|             |/////////|
*-------------*---------*
*/
rect_split_right :: proc(r: Rect, width: f32) -> Rect {
    if width > 0 do return {r.x+r.w-width, r.y, width, r.h}
    else if width < 0 do return {r.x+r.w, r.y, width, r.h}
    return {r.x, r.y+r.w, 0, r.h}
}
/*
   width
*---------*-------------*
|/////////|             |
*---------*-------------*
*/
rect_split_left :: proc(r: Rect, width: f32) -> Rect {
    if width > 0 do return {r.x, r.y, width, r.h}
    else if width < 0 do return {r.x-width, r.y, width, r.h}
    return {r.x, r.y, 0, r.h}
}
rect_split_bottom :: proc(r: Rect, height: f32) -> Rect {
    if height > 0 do return {r.x, r.y, r.w, height}
    else if height < 0 do return {r.x, r.y-height, r.w, height}
    return {r.x, r.y, r.w, 0}
}
rect_split_top :: proc(r: Rect, height: f32) -> Rect {
    if height > 0 do return {r.x, r.y+r.h-height, r.w, height}
    else if height < 0 do return {r.x, r.y+r.h, r.w, height}
    return {r.x, r.y+r.h, r.w, 0}
}