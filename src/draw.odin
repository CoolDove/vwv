package main


import "core:log"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/render"
import "vui"

// rect: xy: min, zw: size

theme : Theme = {
    font_size = 16,
    line_height = 30,
    line_margin = 8,
    line_padding = 8,
    indent_width = 18,
    border_width = 2,
    record_progress_bar_height = 8,

    record_open = {
        normal = {200, 200, 200, 255},
        active = {255, 255, 255, 255},
    },
    record_done = {
        normal = {80, 200, 40, 255},
        active = {65, 212, 60, 255},
    },
    record_closed = {
        normal = {100, 60, 65, 200},
        active = {120, 75, 70, 200},
    },

	text_default = {
		normal = {10,10,10, 255},
		hilight = {4,20,4, 255},
		dimmed = {10,10,10, 128},
	},
	text_record_open = {
		normal = {10,10,10, 255},
		hilight = {4,20,4, 255},
		dimmed = {10,10,10, 128},
	},
	text_record_closed = {
		normal = {25,8,12, 255},
		hilight = {20,18,16, 255},
		dimmed = {10,10,12, 255},
	},
	text_record_done = {
		normal = {10,50,10, 255},
		hilight = {4,60,4, 255},
		dimmed = {10,50,10, 128},
	},

	button_default = {
		normal = {45,45,45, 255},
		hover = {55,55,55, 255},
		active = {70,70,70, 255},
	},
}

Theme :: struct {
    font_size : f32,
    line_height : f32,
    line_margin : f32,
    line_padding : f32,
    indent_width : f32,
    border_width : f32,
    record_progress_bar_height : f32,

	button_default : ButtonTheme,

    // ** colors
    record_open, record_closed, record_done : RecordTheme,
	text_default : TextTheme,
	text_record_open, text_record_closed, text_record_done : TextTheme,
}

RecordTheme :: struct {
	normal, active : Color32
}

ButtonTheme :: struct {
	normal, hover, active : Color32,
}

TextTheme :: struct {
	normal, hilight, dimmed : Color32,
}

_text_theme_default := TextTheme {
	normal = {10,10,10, 255},
	hilight = {4,20,4, 255},
	dimmed = {10,10,10, 128},
}