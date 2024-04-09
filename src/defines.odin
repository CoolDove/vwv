package main


import "vui"



// ** Layers
LAYER_MAIN :i32: 42000

LAYER_FLOATING_PANEL :i32: 68000


// ** VUID

VUID_RECORD_BASE :vui.ID: 42000
// Each record has 256 id for its related vui items.
VUID_BY_RECORD :: proc(r: ^VwvRecord, elem:u8= 0) -> vui.ID {
    return VUID_RECORD_BASE + cast(vui.ID)(r.id * 256) + cast(vui.ID)elem
}
RECORD_ITEM_BUTTON_ADD_RECORD :u8: 4
RECORD_ITEM_LINE_TEXTBOX :u8: 8


VUID_BUTTON_PIN :vui.ID: 48000+1