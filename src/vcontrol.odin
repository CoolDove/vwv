package main

import "core:strings"

import "vui"
import "dude/dude"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/input"
import "dude/dude/render"


record_card :: proc(using ctx: ^vui.VuiContext, id: vui.ID, record: ^VwvRecord, rect: dd.Rect, editting:= false) -> bool {
    using vui
    inrect := _is_in_rect(input.get_mouse_position(), rect)
    result := false
    if active == id {
        if input.get_mouse_button_up(.Left) {
            active = 0
            result = true
        }
    } else {
        if hot == id {
            if inrect {
                if input.get_mouse_button_down(.Left) {
                    active = id
                }
            } else {
                if !inrect do hot = 0
            }
        } else {
            if inrect && active == 0 {
                hot = id
            }
        }
    }
    COL_NORMAL :dd.Color32: {200,200,200, 255}
    COL_HOT :dd.Color32: {222,222,222, 255}
    COL_ACTIVE :dd.Color32: {255,255,255, 255}
    COL_EDIT :dd.Color32: {255,255,255, 255}
    col := COL_NORMAL
    if hot == id do col = COL_HOT
    if active == id do col = COL_ACTIVE
    if editting do col = COL_EDIT

    imdraw.quad(&pass_main, {rect.x,rect.y}, {rect.w,rect.h}, col, order = 42000)
    imdraw.quad(&pass_main, {rect.x,rect.y}+({4,4} if editting else {0,0}), {rect.w,rect.h}, {2,2,2,128}, order = 42000-1)
    if editting do imdraw.quad(&pass_main, {rect.x,rect.y}+{0, rect.h-5}, {rect.w,4}, {240,64,64,255}, order = 42001)
    size :f32= 32
    imdraw.text(&pass_main, render.system().font_unifont, strings.to_string(record.line), {rect.x,rect.y+size}, size, {0,0,0,1}, order = 42001)
    return result
}