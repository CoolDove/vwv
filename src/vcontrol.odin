package main

import "core:strings"

import "vui"
import "dude/dude"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/input"
import "dude/dude/render"


record_card :: proc(using ctx: ^vui.VuiContext, id: vui.ID, record: ^VwvRecord, rect: dd.Rect, editting:= false, measure_line:^dd.Vec2=nil/*output*/, measure_editting:^dd.Vec2=nil/*output*/) -> bool {
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

    using theme
    col := card_normal
    if hot == id do col = card_hover
    if active == id do col = card_active
    if editting do col = card_active

    imdraw.quad(&pass_main, {rect.x,rect.y}, {rect.w,rect.h}, col, order = 42000)
    imdraw.quad(&pass_main, {rect.x,rect.y}+({4,4} if editting else {0,0}), {rect.w,rect.h}, {2,2,2,128}, order = 42000-1)
    font_size :f32= 32
    imdraw.text(&pass_main, font, strings.to_string(record.line), {rect.x,rect.y+font_size}, font_size, {0,0,0,1}, order = 42002)

    editting_text := input.get_textinput_editting_text()
    if editting {
        mesrline := dude.mesher_text_measure(font, strings.to_string(record.line), font_size)
        imdraw.quad(&pass_main, {rect.x,rect.y}+{mesrline.x, 1}, {2,rect.h-2}, {64,200,64,255}, order = 42001)
        imdraw.text(&pass_main, font, editting_text, {rect.x+mesrline.x, rect.y+font_size}, font_size, {.5,.5,.5,1}, order = 42002)

        if measure_line != nil do measure_line^ = mesrline
        if measure_editting != nil && len(editting_text) != 0 do measure_editting^ = dude.mesher_text_measure(font, editting_text, font_size)
    } else {
        if measure_line != nil && len(measure_line) != 0 do measure_line^ = dude.mesher_text_measure(font, strings.to_string(record.line), font_size)
        if measure_editting != nil && len(editting_text) != 0 do measure_editting^ = dude.mesher_text_measure(font, editting_text, font_size)
    }
    
    return result
}