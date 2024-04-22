package main

import "core:strings"
import "core:log"

// ** basic

// ** record manipulations
@(private="file")
_record_next_id :u64= 1

record_add_child :: proc(parent: ^VwvRecord) -> ^VwvRecord {
	append(&parent.children, VwvRecord{})
	child := &(parent.children[len(parent.children)-1])
	record_init(child, parent)
	_record_calculate_progress(parent)
	vwv_mark_save_dirty()
	return child
}

record_arrange :: proc(record: ^VwvRecord, from, to: int) {
    parent := record.parent
    assert(parent != nil, "RecordOperation: Cannot arrange the root node.")
    if from < 0 || from >= len(parent.children) || to < 0 || to >= len(parent.children) || from == to do return
    log.debugf("Apply arrange: {} -> {}", from, to)
    n := record^
    if to < from {
        for i := from; i > to; i-=1 {
            parent.children[i] = parent.children[i-1]
            _set_parent_for_children(parent.children[i].children[:], &parent.children[i])
        }
    } else {
        for i := from; i < to; i+=1 {
            parent.children[i] = parent.children[i+1]
            _set_parent_for_children(parent.children[i].children[:], &parent.children[i])
        }
    }
    parent.children[to] = n
    parent.children[to].parent = parent
    _set_parent_for_children(parent.children[to].children[:], &parent.children[to])

    vwv_mark_save_dirty()
    _set_parent_for_children :: proc(children: []VwvRecord, parent: ^VwvRecord) {
        if DEBUG_VWV do log.debugf("set parent for {} children", len(children))
        for &c in children do c.parent = parent
    }
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
	vwv_mark_save_dirty()
}

record_set_line :: proc(record: ^VwvRecord, line: string) {
	gapbuffer_clear(&record.line)
	gapbuffer_insert_string(&record.line, 0, line)
	vwv_mark_save_dirty()
}

record_set_state :: proc(record: ^VwvRecord, state: VwvRecordState) -> bool {
	if len(record.children) == 0 {
		record.info.state = state
		_record_calculate_progress(record.parent)
		vwv_mark_save_dirty()
		return true
	} else {
		return false
	}
}

record_toggle_fold :: proc(record: ^VwvRecord, fold: bool) {
	if record.fold != fold {
		record.fold = fold
		vwv_mark_save_dirty()
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
	vwv_mark_save_dirty() // Because this changes state.
}
