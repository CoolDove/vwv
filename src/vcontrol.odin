package main

import "core:log"
import "core:strings"
import "core:fmt"

import "vui"
import "dude/dude"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/input"
import "dude/dude/render"


ButtonResult :: enum {
    None, Left, Right,
}

vcontrol_record_card :: proc(using ctx: ^vui.VuiContext, record: ^VwvRecord, rect: dd.Rect, 
                             measure_line:^dd.Vec2=nil/*output*/, measure_editting:^dd.Vec2=nil/*output*/) -> ButtonResult
{
    using vui
    id := VUID_BY_RECORD(record)
    inrect := _is_in_rect(input.get_mouse_position(), rect)
    result := _event_handler_button(ctx, id, inrect)

    using theme
    colors : ^ThemeCardColor

    switch record.info.state {
    case .Open:
        colors = &theme.card_open
    case .Closed:
        colors = &theme.card_closed
    case .Done:
        colors = &theme.card_done
    }
    
    col_bg := colors.normal
    col_text := colors.text_normal
    if active == id {
        col_bg = colors.active
        col_text = colors.text_active
    }

    editting := vwv_app.state == .Edit && vwv_app.editting_record == record
    
    if editting {
        col_bg = colors.active
        col_text = colors.text_active
    }

    corner :dd.Vec2= {rect.x,rect.y}// corner left-top
    corner_rt :dd.Vec2= {rect.x-rect.w,rect.y}// corner right-top
    size :dd.Vec2= {rect.w, rect.h}

    imdraw.quad(&pass_main, corner, size, col_bg, order = LAYER_MAIN)

    // @TEMPORARY:
    record_line := fmt.tprintf("{}{}", gapbuffer_get_left(&record.line), gapbuffer_get_right(&record.line))

    imdraw.text(&pass_main, font, record_line, corner+{0,font_size+line_margin}, font_size, dd.col_u2f(col_text), order = 42002)

    editting_text := input.get_textinput_editting_text()
    if editting {
        mesrline := dude.mesher_text_measure(font, record_line, font_size)

        edit := &vwv_app.text_edit
        editcursor_mesr_next : dd.Vec2
        editcursor_mesr := dude.mesher_text_measure(font, record_line[:edit.selection.x], font_size, out_next_pos =&editcursor_mesr_next)
        imdraw.quad(&pass_main, corner+{editcursor_mesr_next.x, 1}, {2,rect.h-2}, col_text, order = 42001) // draw the cursor

        imdraw.text(&pass_main, font, editting_text, corner+{mesrline.x,font_size+line_margin}, font_size, dd.col_u2f(col_text)*{1,1,1,0.5}, order = 42002) // draw the editting text

        if measure_line != nil do measure_line^ = mesrline
        if measure_editting != nil && len(editting_text) != 0 do measure_editting^ = dude.mesher_text_measure(font, editting_text, font_size)
    } else {
        if measure_line != nil && len(measure_line) != 0 do measure_line^ = dude.mesher_text_measure(font, record_line, font_size)
        if measure_editting != nil && len(editting_text) != 0 do measure_editting^ = dude.mesher_text_measure(font, editting_text, font_size)
    }

    // ** draw the state or progress
    if record.info.state == .Closed {
        imdraw.quad(&pass_main, corner+{2,0.5*size.y-1}, {size.x-4, 2}, {10,10,5,128}, order=42003)
    }

    if len(record.children) != 0 {// ** draw the progress bar
        padding_horizontal :f32= 16
        pgb_length_total :f32= size.x - padding_horizontal
        pgb_thickness :f32= 9
        if pgb_length_total > 0 {
            x := corner.x + 0.5 * padding_horizontal
            y := corner.y + size.y - 12
            progress := record.info.progress
            done, open, closed := progress[1], progress[0], progress[2]

            progress_message := fmt.tprintf("%.2f%%", (done / (1-closed)) * 100)
            msg_measure := dude.mesher_text_measure(font, progress_message, font_size * 0.25)
            imdraw.text(&pass_main, font, progress_message, {x + pgb_length_total - msg_measure.x, y + pgb_thickness-2}, font_size * 0.25, {0,0,0, 0.86}, order=42002)

            // ** progress bar background
            imdraw.quad(&pass_main, {x,y+pgb_thickness}, {pgb_length_total, 1}, {10,10,20, 255}, order=42001)

            // ** progress bar
            alpha :u8= 128
            imdraw.quad(&pass_main, {x,y}, {pgb_length_total*done, pgb_thickness}, {20,180,20, alpha}, order=42001)
            x += pgb_length_total*done
            imdraw.quad(&pass_main, {x,y}, {pgb_length_total*open, pgb_thickness}, {128,128,128, alpha}, order=42001)
            x += pgb_length_total*open
            imdraw.quad(&pass_main, {x,y}, {pgb_length_total*closed, pgb_thickness}, {180,30,15, alpha}, order=42001)
            
        }
    }

    return result
}

vcontrol_button_add_record :: proc(using ctx: ^vui.VuiContext, record: ^VwvRecord, rect: dd.Rect) -> ButtonResult {
    using vui
    id := VUID_BY_RECORD(record, RECORD_ITEM_BUTTON_ADD_RECORD)
    inrect := _is_in_rect(input.get_mouse_position(), rect)
    result := _event_handler_button(ctx, id, inrect)

    using theme
    col :dd.Color32= {65,65,65, 255}
    if hot == id do col = {80,80,80, 255}
    if active == id do col = {95,95,95, 255}
    imdraw.quad(&pass_main, {rect.x,rect.y+0.5*rect.h-2}, {rect.w,4}, col, order=LAYER_MAIN + 1)
    imdraw.quad(&pass_main, {rect.x+0.5*rect.w-2,rect.y}, {4,rect.h}, col, order=LAYER_MAIN + 1)
    return result
}

@(private="file")
_event_handler_button :: proc(using ctx: ^vui.VuiContext, id: vui.ID, inrect: bool) -> ButtonResult {
    using vui
    result := ButtonResult.None
    if active == id {
        if input.get_mouse_button_up(.Left) {
            active = 0
            if inrect {
                result = .Left
            }
        } else if input.get_mouse_button_up(.Right) {
            active = 0
            if inrect {
                result = .Right
            }
        }
    } else {
        if hot == id {
            if inrect {
                if input.get_mouse_button_down(.Left) || input.get_mouse_button_down(.Right) {
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
    return result
}