package main

import "core:strings"

// ** basic

// ** record manipulations
record_add_child :: proc(parent: ^VwvRecord) -> ^VwvRecord {
	append(&parent.children, VwvRecord{})
	child := &(parent.children[len(parent.children)-1])
	strings.builder_init(&child.line)
	strings.builder_init(&child.detail)
	child.children = make([dynamic]VwvRecord)
	child.parent = parent
	_record_calculate_progress(parent)
	return child
}

record_set_line :: proc(record: ^VwvRecord, line: string) {
	strings.builder_reset(&record.line)
	strings.write_string(&record.line, line)
}

record_set_state :: proc(record: ^VwvRecord, state: VwvRecordState) -> bool {
	if len(record.children) == 0 {
		record.info.state = state
		_record_calculate_progress(record.parent)
		return true
	} else {
		return false
	}
}

_record_calculate_progress :: proc(using record: ^VwvRecord) {
	if record == nil do return
	if len(children) != 0 {
		count : [3]f32
		for c in children {
			switch c.info.state {
			case .Open:		count[0]+=1
			case .Done:		count[1]+=1
			case .Closed:	count[2]+=1
			}
		}
		sum := count[0]+count[1]+count[2]
		record.info.progress = count / sum

		record.info.state = .Done if record.info.progress[0] == 0 else .Open
	}
	_record_calculate_progress(parent)
}