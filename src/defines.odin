package main


import "vui"



// ** Layers
LAYER_MAIN :i32: 42000

LAYER_FLOATING_PANEL :i32: 68000



// Each record has 256 id for its related vui items.
VUID_BY_RECORD :: proc(r: ^VwvRecord, elem:u8= 0) -> vui.ID {
    return VUID_RECORD_BASE + cast(vui.ID)(r.id * 256) + cast(vui.ID)elem
}

VUID_RECORD_BASE :vui.ID: 42000