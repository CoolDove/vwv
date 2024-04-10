package main

import "core:os"
import "core:log"
import "core:fmt"
import "core:path/filepath"
import "core:encoding/json"

import "dude/dude"

VWV_PATH :: "vwv"
PATH_RECORDS :: ".records"
PATH_CONFIGS :: ".configs"


RecordStorage :: struct {
    line, detail : string,
    tag : u32,
    state : VwvRecordState,
    children_count : int,
    fold : bool,
}

is_record_file_exist :: proc() -> bool {
    return os.exists(_get_path_temp(PATH_RECORDS))
}

save :: proc() {
    dude.timer_check("Save begins")
    dumped := make([dynamic]RecordStorage)
    _dump(&dumped, &root)
    opt : json.Marshal_Options
    opt.spec = .JSON5
    data, _ := json.marshal(dumped); defer delete(data)

    os.make_directory(_get_vwv_path_temp())

    path := _get_path_temp(PATH_RECORDS)
    log.debugf("write path: {}", path)
    os.write_entire_file(path, data)

    bubble_msg("Saved", 0.8)

    for r in dumped {
        delete(r.line)
        delete(r.detail)
    }
    delete(dumped)
    dude.timer_check("Save ends")
}
load :: proc() {// The root record is initialized before this.
    path := _get_path_temp(PATH_RECORDS)
    log.debugf("read path: {}", path)
    data, _ := os.read_entire_file(path); defer delete(data)
    buffer : []RecordStorage
    json.unmarshal(data, &buffer)
    ptr := 0
    _apply(buffer, &ptr, &root)

    for r in buffer {
        delete(r.line)
        delete(r.detail)
    }
    delete(buffer)
}

@(private="file")
_dump :: proc(buffer: ^[dynamic]RecordStorage, record: ^VwvRecord) {
    line := gapbuffer_get_string(&record.line)
    detail := gapbuffer_get_string(&record.detail)
    append(buffer, RecordStorage{
        line = line,
        detail = detail,
        tag = record.info.tag,
        state = record.info.state,
		fold = record.info.fold,
        children_count = len(record.children),
    })
    for &c in record.children {
        _dump(buffer, &c)
    }
}

@(private="file")
_apply :: proc(buffer: []RecordStorage, ptr: ^int, record: ^VwvRecord) {
    rs := buffer[ptr^]
    record_set_line(record, rs.line)
    record_set_state(record, rs.state)
	record_toggle_fold(record, rs.fold)
    children_count := rs.children_count
    ptr^ += 1

    for i in 0..<children_count {
        _apply(buffer, ptr, record_add_child(record))
    }
}

@(private="file")
_get_path_temp :: proc(path : string) -> string {
    return filepath.join({user_directory(), VWV_PATH, path}, context.temp_allocator)
}
@(private="file")
_get_vwv_path_temp :: proc() -> string {
    return filepath.join({user_directory(), VWV_PATH}, context.temp_allocator)
}