package main

import "core:strings"

record_add_child :: proc(parent: ^VwvRecord) -> ^VwvRecord {
	append(&parent.children, VwvRecord{})
	child := &(parent.children[len(parent.children)-1])
	strings.builder_init(&child.line)
	strings.builder_init(&child.detail)
	child.children = make([dynamic]VwvRecord)
	return child
}

record_set_line :: proc(record: ^VwvRecord, line: string) {
	strings.builder_reset(&record.line)
	strings.write_string(&record.line, line)
}

record_set_state :: proc(record: ^VwvRecord, state: VwvRecordState) -> bool {
	if len(record.children) == 0 {
		record.info.state = state
		return true
	} else {
		return false
	}
}