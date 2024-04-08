package main


import "core:log"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/render"
import "vui"

// rect: xy: min, zw: size

theme : Theme = {
    line_height = 40,
    line_padding = 8,
    indent_width = 12,
    border_width = 2,

    card_open = {
        normal = {200, 200, 200, 255},
        active = {255, 255, 255, 255},
        text_normal = {20,20,20, 255},
        text_active = {0,0,0, 255},
    },
    card_done = {
        normal = {20, 200, 20, 255},
        active = {20, 255, 20, 255},
        text_normal = {20,20,20, 255},
        text_active = {0,0,0, 255},
    },
    card_closed = {
        normal = {160, 10, 10, 255},
        active = {180, 20, 10, 255},
        text_normal = {180,160,160, 255},
        text_active = {190,160,160, 255},
    },
}

Theme :: struct {
    line_height : f32,
    line_padding : f32,
    indent_width : f32,
    border_width : f32,

    // ** colors
    card_open, card_closed, card_done : ThemeCardColor,
}

ThemeCardColor :: struct {
    normal, active, text_normal, text_active : dd.Color32
}