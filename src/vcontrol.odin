package main

import "core:strings"

import "vui"
import "dude/dude"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/input"
import "dude/dude/render"

record_card :: proc(using ctx: ^vui.VuiContext, id: vui.ID, record: ^VwvRecord, rect: dd.Rect, editting:= false, measure_line:^dd.Vec2=nil, measure_editting:^dd.Vec2=nil) -> bool {
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
    size :f32= 32
    imdraw.text(&pass_main, font, strings.to_string(record.line), {rect.x,rect.y+size}, size, {0,0,0,1}, order = 42001)

    measure_line_value : Vec2

    if editting {
        measure_line_value := dude.mesher_text_measure(font, strings.to_string(record.line), size)
        editting_text := input.get_textinput_editting_text()

        if measure_line != nil do measure_line^ = measure_line_value
        if measure_editting != nil {
            measure_editting^ = dude.mesher_text_measure(font, editting_text, size)
        }

        imdraw.text(&pass_main, font, editting_text, {rect.x+measure_line_value.x,rect.y+size}, size, {.5,.5,.5,1}, order = 42001)
        imdraw.quad(&pass_main, {rect.x+measure_line_value.x,rect.y+4}, {6, size}, {64,240,64,255}, order = 42001)
    } else {
        if measure_line != nil {
            measure_line_value := dude.mesher_text_measure(font, strings.to_string(record.line), size)
            measure_line^ = measure_line_value
        } 
        if measure_editting != nil {
            editting_text := input.get_textinput_editting_text()
            measure_editting^ = dude.mesher_text_measure(font, editting_text, size)
        }
    }
    return result
}