package main

import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:math"
import "core:strings"

import "dude/dude"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/input"
import "dude/dude/render"
import "dude/dude/vendor/fontstash"
import "vui"

@(private = "file")
VID :: vui.ID

ButtonResult :: enum {
	None,
	Left,
	Right, // Click event, triggered by a button up.
	Drag,
	DragRelease,
}

@(private = "file")
RecordCardController :: struct {
	clicked_position: dd.Vec2, // Where you pressed down, used to identify a drag.
}

vbegin_record_card :: proc(using ctx: ^vui.VuiContext, record: ^VwvRecord) {
	vui.push_stack(ctx, cast(i32)record.id, 8, auto_cast LAYER_RECORD_BASE)
}

vend_record_card :: proc(
	using ctx: ^vui.VuiContext,
	record: ^VwvRecord,
	rect: dd.Rect,
	handle_event := true,
	render_layer_offset: i32 = 0,
) -> ButtonResult {
	using vui
	stack := vui.peek_stack(ctx);defer vui.pop_stack(ctx)
	id := VUID_BY_RECORD(record)
	mouse_position := input.get_mouse_position()
	inrect := rect_in(rect, mouse_position)
	for r in stack.rects {
		if rect_in(r, mouse_position) {
			inrect = false
			break
		}
	}
	result: ButtonResult
	if handle_event {
		controller := vui.get_state(ctx, RecordCardController)
		if dragging != id && (active == id || active == 0) {
			vui._handle_hot(ctx, inrect, id, auto_cast LAYER_RECORD_BASE)
		}
		if dragging == id {
			strings.write_string(&vwv_app.status_bar_info, fmt.tprintf("[dragging {}...]", id))
			if input.get_mouse_button_up(.Left) || input.get_mouse_button_up(.Right) {
				dragging = 0
				result = .DragRelease
			}
		} else if active == id {
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
			} else {
				drag_threshold: f32 = theme.line_height
				drag_distance := linalg.distance(
					input.get_mouse_position(),
					controller.clicked_position,
				)
				if drag_distance > drag_threshold {
					active = 0
					dragging = id
					return .Drag
				}
			}
		} else {
			if hot == id {
				if input.get_mouse_button_down(.Left) || input.get_mouse_button_down(.Right) {
					active = id
					vui.set_state(
						ctx,
						RecordCardController{clicked_position = input.get_mouse_position()},
					)
				}
			}
		}
	}

	using theme
	colors: ^RecordTheme

	switch record.info.state {
	case .Open:
		colors = &theme.record_open
	case .Closed:
		colors = &theme.record_closed
	case .Done:
		colors = &theme.record_done
	}

	editting := vwv_app.state == .Edit && vwv_app.editting_record == record

	col_bg := colors.normal
	if active == id || editting {
		col_bg = colors.active
	}

	corner: Vec2 = {
		rect.x,
		rect.y,
	} 	// corner left-top
	corner_rt: Vec2 = {
		rect.x - rect.w,
		rect.y,
	} 	// corner right-top
	size: Vec2 = {rect.w, rect.h}

	_LAYER_RECORD_BASE := LAYER_RECORD_BASE + render_layer_offset
	_LAYER_PROGRESS_BAR := LAYER_RECORD_CONTENT - 60 + render_layer_offset
	_LAYER_OVERLAY := LAYER_RECORD_CONTENT + 100 + render_layer_offset

	// ** draw the card background
	imdraw.quad(pass, corner, size, col_bg, order = _LAYER_RECORD_BASE)

	// ** draw the closed slash line
	if record.info.state == .Closed {
		imdraw.quad(
			pass,
			corner + {2, 0.5 * size.y - 1},
			{size.x - 4, 2},
			{10, 10, 5, 128},
			order = _LAYER_OVERLAY,
		)
	}

	// ** draw the progress bar
	if len(record.children) != 0 {
		padding_horizontal: f32 = 50
		pgb_length_total: f32 = size.x - padding_horizontal - 16
		pgb_thickness: f32 = theme.record_progress_bar_height
		if pgb_length_total > 0 {
			x := corner.x + 16
			y := corner.y + size.y - 12
			progress := record.info.progress
			done, open, closed := progress[1], progress[0], progress[2]

			progress_message := fmt.tprintf(
				"%.2f%%",
				((done / (1 - closed)) * 100) if closed != 1 else 100,
			)
			msg_measure := dude.mesher_text_measure(font, progress_message, font_size * 0.25)
			// ** progress bar background
			imdraw.quad(
				pass,
				{x, y + pgb_thickness},
				{pgb_length_total, 1},
				{10, 10, 20, 255},
				order = _LAYER_PROGRESS_BAR,
			)

			// ** progress bar
			alpha: u8 = 128
			imdraw.quad(
				pass,
				{x, y},
				{pgb_length_total * done, pgb_thickness},
				{20, 180, 20, alpha},
				order = _LAYER_PROGRESS_BAR,
			)
			x += pgb_length_total * done
			imdraw.quad(
				pass,
				{x, y},
				{pgb_length_total * open, pgb_thickness},
				{128, 128, 128, alpha},
				order = _LAYER_PROGRESS_BAR,
			)
			x += pgb_length_total * open
			imdraw.quad(
				pass,
				{x, y},
				{pgb_length_total * closed, pgb_thickness},
				{180, 30, 15, alpha},
				order = _LAYER_PROGRESS_BAR,
			)
		}
	}

	if DEBUG_VWV {
		debug_msg := fmt.tprintf("id: {}, parent: {}", record.id, record.parent.id)
		imdraw.text(
			pass,
			render.system().default_font,
			debug_msg,
			rect_position(rect) + {0, 12},
			12,
			color = {0, 0, 1, 1},
			order = 999998,
		)

	}
	return result
}

vcontrol_checkbox :: proc(
	using ctx: ^vui.VuiContext,
	id: VID,
	rect: Rect,
	value: bool,
	icon :Icon={},
	order := LAYER_RECORD_CONTENT,
	btntheme := theme.button_default,
) -> bool {
	using vui
	id := vui.get_real_id(ctx, auto_cast id)
	order := vui.get_real_layer(ctx, auto_cast order)

	inrect := rect_in(rect, input.get_mouse_position())
	push_rect(ctx, rect)
	pressed := false
	if active == id || active == 0 {
		vui._handle_hot(ctx, inrect, id, auto_cast order)
	}
	if active == id {
		if input.get_mouse_button_up(.Left) {
			active = 0
			if inrect {
				pressed = true
			}
		}
	} else {
		if hot == id && input.get_mouse_button_down(.Left) {
			active = id
		}
	}

	col := btntheme.normal
	if value do col = btntheme.active
	else if hot == id do col = btntheme.hover

	if icon != {} {
		imdraw.quad(pass, {rect.x, rect.y}, {rect.w, rect.h}, col, texture = ICON_TEXTURE.id, order = auto_cast order, uv_min=rect_position(auto_cast icon), uv_max=rect_max(auto_cast icon))
		imdraw.quad(pass, {rect.x+2, rect.y+2}, {rect.w, rect.h}, {0,0,0,32}, texture = ICON_TEXTURE.id, order = auto_cast order-1, uv_min=rect_position(auto_cast icon), uv_max=rect_max(auto_cast icon))
	} else {
		imdraw.quad(pass, {rect.x, rect.y}, {rect.w, rect.h}, col, order = auto_cast order)
	}

	return !value if pressed else value
}

vcontrol_button :: proc(
	using ctx: ^vui.VuiContext,
	id: VID,
	rect: Rect,
	order := LAYER_MAIN,
	icon : Icon={},
	btntheme := theme.button_default,
) -> bool {
	id := vui.get_real_id(ctx, auto_cast id)
	order := vui.get_real_layer(ctx, auto_cast order)

	inrect := rect_in(rect, input.get_mouse_position())
	result := false
	vui.push_rect(ctx, rect)

	if active == id || active == 0 {
		vui._handle_hot(ctx, inrect, id, auto_cast order)
	}
	if active == id {
		if input.get_mouse_button_up(.Left) {
			active = 0
			if inrect {
				result = true
				vui._reset(ctx)
			}
		}
	} else {
		if hot == id && input.get_mouse_button_down(.Left) {
			active = id
		}
	}

	col := btntheme.normal
	if hot == id do col = btntheme.hover
	if active == id do col = btntheme.active

	if icon != {} {
		imdraw.quad(pass, {rect.x, rect.y}, {rect.w, rect.h}, col, texture = ICON_TEXTURE.id, order = auto_cast order, uv_min=rect_position(auto_cast icon), uv_max=rect_max(auto_cast icon))
		imdraw.quad(pass, {rect.x+2, rect.y+2}, {rect.w, rect.h}, {0,0,0,32}, texture = ICON_TEXTURE.id, order = auto_cast order-1, uv_min=rect_position(auto_cast icon), uv_max=rect_max(auto_cast icon))
	} else {
		imdraw.quad(pass, {rect.x, rect.y}, {rect.w, rect.h}, col, order = auto_cast order)
	}

	return result
}

// An invisible empty ui contorl. To block interactions to other controls.
// Acts like a button, but does nothing.
vcontrol_panel :: proc(using ctx: ^vui.VuiContext, id: VID, rect: Rect, order := LAYER_MAIN) {
	id := vui.get_real_id(ctx, auto_cast id)
	order := vui.get_real_layer(ctx, auto_cast order)

	inrect := rect_in(rect, input.get_mouse_position())
	result := false
	vui.push_rect(ctx, rect)
	if active == id || active == 0 {
		vui._handle_hot(ctx, inrect, id, auto_cast order)
	}
	if active == id {
		if input.get_mouse_button_up(.Left) {
			active = 0
			if inrect {
				result = true
			}
		}
	} else {
		if hot == id && input.get_mouse_button_down(.Left) {
			active = id
		}
	}
}

// If `edit` is nil, this control will only display the text. You pass in a edit, the control will
//  work.
//  Return: Click outside or press `ESC` or `RETURN` to exit the edit.
vcontrol_edittable_textline :: proc(
	using ctx: ^vui.VuiContext,
	id: VID,
	rect: Rect,
	layer: i32,
	buffer: ^GapBuffer,
	edit: ^TextEdit = nil,
	ttheme := theme.text_default,
) -> (
	edit_point: Vec2,
	exit: bool,
) {
	using vui
	id := vui.get_real_id(ctx, auto_cast id)
	order := vui.get_real_layer(ctx, auto_cast layer)

	inrect := rect_in(rect, input.get_mouse_position())
	result := false
	rcorner, rsize := rect_position(rect), rect_size(rect)
	editting := edit != nil

	if editting { 	// Manually enable the text editting.
		if edit.buffer != buffer do textedit_begin(edit, buffer, gapbuffer_len(buffer))

		active = id
		vui._handle_hot(ctx, inrect, id, auto_cast layer)

		if (!inrect &&
			(input.get_mouse_button_up(.Left) || input.get_mouse_button_up(.Right))) ||
			(input.get_key_up(.ESCAPE) || input.get_key_up(.RETURN)) // Click outside// Press ESC or RETURN
		{
			result = true
			vui._reset(ctx)
		}

		// ** text editting logic
		ed := edit
		if str, ok := input.get_textinput_charactors_temp(); ok {
			textedit_insert(ed, str)
			dd.dispatch_update()
		}

		if input.get_key_repeat(.LEFT) {
			to: int = -1
			if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
				to = textedit_find_previous_word_head(ed, ed.selection.x)
			} else {
				_, to = textedit_find_previous_rune(ed, ed.selection.x)
			}
			if to > -1 do textedit_move_to(ed, to)
		} else if input.get_key_repeat(.RIGHT) {
			to: int = -1
			if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
				to = textedit_find_next_word_head(ed, ed.selection.x)
			} else {
				_, to = textedit_find_next_rune(ed, ed.selection.x)
			}
			if to > -1 do textedit_move_to(ed, to)
		}

		if input.get_key_repeat(.BACKSPACE) {
			to: int = -1
			if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
				to = textedit_find_previous_word_head(ed, ed.selection.x)
			} else {
				_, to = textedit_find_previous_rune(ed, ed.selection.x)
			}
			if to > -1 do textedit_remove(ed, to - ed.selection.x)
		} else if input.get_key_repeat(.DELETE) {
			to: int = -1
			if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
				to = textedit_find_next_word_head(ed, ed.selection.x)
			} else {
				_, to = textedit_find_next_rune(ed, ed.selection.x)
			}
			if to > -1 do textedit_remove(ed, to - ed.selection.x)
		}
		if input.get_key_down(.HOME) {
			textedit_move_to(ed, 0)
		} else if input.get_key_down(.END) {
			textedit_move_to(ed, gapbuffer_len(ed.buffer))
		}
	}

	if DEBUG_VWV {
		imdraw.quad(pass, rcorner, rsize, {255, 120, 230, 40}, order = layer)
	}

	text_line := gapbuffer_get_string(buffer);defer delete(text_line)

	ttbro : dude.TextBro
	dude.tbro_init(&ttbro, vuictx.font, theme.font_size); defer dude.tbro_release(&ttbro)

	internal_font := dude.get_font(font)
	using theme
	if editting {
		cursor_pos := rcorner + {0, internal_font.lineHeight}
		text_pos := rcorner + {0, rect.h - internal_font.lineHeight - line_margin}
		config := dude.TextBroExportConfig{color=ttheme.dimmed, transform=dude.mat3_trs(text_pos, 0,1)}
		if input.get_textinput_editting_text() != "" {
			tbro_idx_before_edit := dude.tbro_write_string(&ttbro, text_line[:edit.selection.x])
			tbro_idx_after_edit := dude.tbro_write_string(&ttbro, input.get_textinput_editting_text())
			tbro_idx_last := dude.tbro_write_string(&ttbro, text_line[edit.selection.x:])

			edit_offset :f32= math.max(dude.tbro_next_pos(&ttbro, tbro_idx_before_edit).x - rect.w*0.7, 0)

			edit_point = cursor_pos + {dude.tbro_next_pos(&ttbro, tbro_idx_before_edit).x - edit_offset, rsize.y-2}
			cursor_pos += {dude.tbro_next_pos(&ttbro, tbro_idx_after_edit).x - edit_offset, 0}

			config.transform = dude.mat3_trs(text_pos-{edit_offset, 0}, 0,1)
			dude.tbro_config_clamp(&config, true, { edit_offset, -999, rect.w, 2*999 })

			imdraw.textbro(&pass_main, &ttbro, tbro_idx_before_edit+1, tbro_idx_after_edit, config, layer)
			config.color = ttheme.normal
			if tbro_idx_before_edit>0 do imdraw.textbro(&pass_main, &ttbro, 0, tbro_idx_before_edit, config, layer)
			if tbro_idx_last>tbro_idx_after_edit do imdraw.textbro(&pass_main, &ttbro, tbro_idx_after_edit+1, tbro_idx_last, config, layer)
		} else {
			idx_before := dude.tbro_write_string(&ttbro, text_line[:edit.selection.x])
			dude.tbro_write_string(&ttbro, text_line[edit.selection.x:])
			config.color = ttheme.normal
			edit_offset :f32= math.max(dude.tbro_next_pos(&ttbro, idx_before).x - rect.w*0.7, 0)
			config.transform = dude.mat3_trs(text_pos-{edit_offset, 0}, 0,1)
			dude.tbro_config_clamp(&config, true, { edit_offset, -999, rect.w, 2*999 })

			cursor_pos += {dude.tbro_next_pos(&ttbro, idx_before).x-edit_offset, 0}
			edit_point = cursor_pos+{0,rsize.y-2}

			if dude.tbro_length(&ttbro)!=0 do imdraw.textbro(&pass_main, &ttbro, 0, dude.tbro_length(&ttbro)-1, config, layer)
		}
		imdraw.quad(
			pass,
			cursor_pos,
			{2, rsize.y - 2},
			ttheme.normal,
			order = layer,
		) // draw the cursor
	} else {
		text_pos := rcorner + {0, rect.h -  internal_font.lineHeight - line_margin}
		config := dude.TextBroExportConfig{color=ttheme.normal, transform=dude.mat3_trs(text_pos, 0,1)}
		config.clamp_enable = true
		config.clamp_rect = {0,-999, rect.w, 2*999}
		// Test the rotation
		// config := dude.TextBroExportConfig{color=ttheme.normal, transform=dude.mat3_trs(text_pos, 15*math.RAD_PER_DEG,1)}

		dude.tbro_write_string(&ttbro, text_line)
		if len(ttbro.elems) != 0 do imdraw.textbro(&pass_main, &ttbro, 0, dude.tbro_length(&ttbro)-1, config, layer)
		edit_point = {}
	}

	exit = result
	return
}
