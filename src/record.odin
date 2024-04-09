package main

import "core:strings"

// ** basic

// ** record manipulations
@(private="file")
_record_next_id :u64= 1



record_add_child :: proc(parent: ^VwvRecord) -> ^VwvRecord {
	append(&parent.children, VwvRecord{})
	child := &(parent.children[len(parent.children)-1])
    record_init(child, parent)
	_record_calculate_progress(parent)
	return child
}

record_remove_record :: proc(record: ^VwvRecord) {
    if record.parent == nil do return
    record_release_recursively(record)
    #reverse for &c, i in record.parent.children {
        if &c == record {
            ordered_remove(&record.parent.children, i)
            break
        }
    }
}

record_set_line :: proc(record: ^VwvRecord, line: string) {
    gapbuffer_clear(&record.line)
    gapbuffer_insert_string(&record.line, 0, line)
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


record_init :: proc(r: ^VwvRecord, parent: ^VwvRecord=nil) {
    gapbuffer_init(&r.line, 32)
    gapbuffer_init(&r.detail, 32)
    r.children = make([dynamic]VwvRecord)
    r.parent = parent
	r.id = _record_next_id
	_record_next_id += 1
}
record_release_recursively :: proc(r: ^VwvRecord) {
    for &c in r.children {
        record_release_recursively(&c)
    }
    delete(r.children)
    gapbuffer_release(&r.line)
    gapbuffer_release(&r.detail)
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