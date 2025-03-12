package main

import "core:strings"
import "core:path/filepath"
import "core:io"
import "core:os"
import "core:log"
import "core:encoding/json"

VERSION :: enum {
	V01,
	// ... add here

	LATEST=V01,
}

// Should have the root node prepared before this
doc_read :: proc() {
	target_dir := _confirm_target_directory(context.temp_allocator)
	target_file := filepath.join({target_dir, ".records"}, context.temp_allocator)
	if !os.exists(target_file) do return
	fileread_ok : bool
	data : []u8
	if data, fileread_ok = os.read_entire_file(target_file, context.temp_allocator); fileread_ok {
		jd, err := json.parse(data); defer json.destroy_value(jd)
		if err == nil {
			if _, is_array := jd.(json.Array); is_array {
				_read_legacy(jd)
			} else if storage, is_object := jd.(json.Object); is_object {
				switch cast(VERSION)cast(int)storage["version"].(json.Float) {
				case .V01:
					_read_v01(jd)
				}
			}
		}
	}
}

doc_write :: proc() {
	StorageRecord :: struct {
		text : string,
		children_count : int,
	}
	Storage :: struct {
		version : VERSION,
		records : [dynamic]StorageRecord,
	}
	sb : strings.Builder
	strings.builder_init(&sb); defer strings.builder_destroy(&sb)
	storage : Storage
	storage.version = .LATEST
	storage.records = make([dynamic]StorageRecord); defer delete(storage.records)

	ite :: proc(r: ^Record, array : ^[dynamic]StorageRecord, depth:= 0) {
		append(array, StorageRecord{})
		idx := len(array)-1
		text := strings.to_string(r.text)
		count := 0
		ptr := r.child
		for ptr != nil {
			ite(ptr, array, depth+1)
			count += 1
			ptr = ptr.next
		}
		array[idx] = {
			text = text,
			children_count = count
		}
	}

	ite(root, &storage.records)

	opt : json.Marshal_Options
	opt.pretty = true
	json.marshal_to_builder(&sb, storage, &opt)
	log.debugf("write: \n{}", strings.to_string(sb))
	target_dir := _confirm_target_directory(context.temp_allocator)
	target_file := filepath.join({target_dir, ".records"}, context.temp_allocator)
	os.write_entire_file(target_file, transmute([]u8)strings.to_string(sb))
}

@(private="file")
_read_v01 :: proc(value: json.Value) {
	value := value.(json.Object)
	records := value["records"].(json.Array)

	Node :: #type struct { r, last_child: ^Record, children : int }
	current := make([dynamic]Node); defer delete(current)
	using json
	for r, idx in records {
		if idx == 0 do continue
		record : ^Record
		data := r.(Object)
		if len(current) == 0 {
			record = record_append_child(root)
			strings.write_string(&record.text, data["text"].(String))
		} else {
			crnt := &current[len(current)-1]
			if crnt.last_child == nil do record = record_add_child(crnt.r)
			else do record = record_add_sibling(crnt.last_child) // record_append_child(crnt.r)
			strings.write_string(&record.text, data["text"].(String))
			crnt.children -= 1
			crnt.last_child = record
		}
		if children := cast(int)data["children_count"].(Float); children > 0 {
			append(&current, Node{record, nil, children})
		}

		length := len(current)
		for i in 0..<len(current) {
			i := length-1-i
			if current[i].children > 0 {
				break
			}
			pop(&current)
		}
	}
	
}

@(private="file")
_read_legacy :: proc(value: json.Value) {
	Node :: #type struct { r: ^Record, children : int }
	current := make([dynamic]Node)
	defer delete(current)

	using json
	for r in value.(Array) {
		record : ^Record
		if len(current) == 0 {
			record = record_add_child(root)
			strings.write_string(&record.text, r.(Object)["line"].(String))
		} else {
			crnt := &current[len(current)-1]
			record = record_add_child(crnt.r)
			strings.write_string(&record.text, r.(Object)["line"].(String))
			crnt.children -= 1
		}
		if children := cast(int)r.(Object)["children_count"].(Float); children > 0 {
			append(&current, Node{record, children})
		}

		length := len(current)
		for i in 0..<len(current) {
			i := length-1-i
			if current[i].children == 0 do pop(&current)
		}
	}
}


// ** helpers

@(private="file")
_confirm_target_directory :: proc(allocator:= context.allocator) -> string {
	context.allocator = allocator
	target_dir := _get_target_dir()
	if !os.exists(target_dir) do os.make_directory(target_dir)
	return target_dir
}

@(private="file")
_get_target_dir :: proc(allocator:= context.allocator) -> string {
	context.allocator = allocator
	return filepath.join({os.get_env("USERPROFILE"), "vwv"})
}

@(private="file")
_get_target_file :: proc(allocator:= context.allocator) -> string {
	context.allocator = allocator
	return filepath.join({os.get_env("USERPROFILE"), "vwv", ".records"})
}
