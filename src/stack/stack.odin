package container_stack

import "base:builtin"
import "base:runtime"
_ :: runtime

// Dynamically resizable stack (LIFO container)
Stack :: struct($T: typeid) {
	data: [dynamic]T,
	len:  uint,
}

DEFAULT_CAPACITY :: 16

// Initialize a stack with the given capacity
init :: proc(s: ^$S/Stack($T), capacity := DEFAULT_CAPACITY, allocator := context.allocator) -> runtime.Allocator_Error {
	if s.data.allocator.procedure == nil {
		s.data.allocator = allocator
	}
	clear(s)
	return reserve(s, capacity)
}

// Initialize a stack from a fixed backing slice
init_from_slice :: proc(s: ^$S/Stack($T), backing: []T) -> bool {
	clear(s)
	s.data = transmute([dynamic]T)runtime.Raw_Dynamic_Array{
		data = raw_data(backing),
		len = builtin.len(backing),
		cap = builtin.len(backing),
		allocator = {procedure=runtime.nil_allocator_proc, data=nil},
	}
	return true
}

// Initialize a stack from a fixed backing slice, preserving contents
init_with_contents :: proc(s: ^$S/Stack($T), backing: []T) -> bool {
	clear(s)
	s.data = transmute([dynamic]T)runtime.Raw_Dynamic_Array{
		data = raw_data(backing),
		len = builtin.len(backing),
		cap = builtin.len(backing),
		allocator = {procedure=runtime.nil_allocator_proc, data=nil},
	}
	s.len = uint(len(backing))
	return true
}

// Destroy the stack and free its memory
destroy :: proc(s: ^$S/Stack($T)) {
	delete(s.data)
}

// Get the number of elements in the stack
len :: proc(s: $S/Stack($T)) -> int {
	return int(s.len)
}

// Get the current capacity of the stack
cap :: proc(s: $S/Stack($T)) -> int {
	return builtin.len(s.data)
}

// Get remaining space in the stack (cap - len)
space :: proc(s: $S/Stack($T)) -> int {
	return cap(s) - len(s)
}

// Reserve space for at least specified capacity
reserve :: proc(s: ^$S/Stack($T), capacity: int) -> runtime.Allocator_Error {
	if capacity > cap(s^) {
		current_cap := uint(builtin.len(s.data))
		new_capacity := max(uint(capacity), 8, current_cap * 2)
		builtin.resize(&s.data, int(new_capacity)) or_return
	}
	return nil
}

// Get element at index (0 = bottom, len-1 = top)
get :: proc(s: ^$S/Stack($T), #any_int i: int, loc := #caller_location) -> T {
	runtime.bounds_check_error_loc(loc, i, int(s.len))
	return s.data[i]
}

// Get pointer to element at index
get_ptr :: proc(s: ^$S/Stack($T), #any_int i: int, loc := #caller_location) -> ^T {
	runtime.bounds_check_error_loc(loc, i, int(s.len))
	return &s.data[i]
}

// Set element at index
set :: proc(s: ^$S/Stack($T), #any_int i: int, val: T, loc := #caller_location) {
	runtime.bounds_check_error_loc(loc, i, int(s.len))
	s.data[i] = val
}

// Get top element of the stack
top :: proc(s: ^$S/Stack($T), loc := #caller_location) -> T {
	assert(s.len > 0, loc=loc)
	return s.data[s.len - 1]
}

// Get pointer to top element
top_ptr :: proc(s: ^$S/Stack($T), loc := #caller_location) -> ^T {
	assert(s.len > 0, loc=loc)
	return &s.data[s.len - 1]
}

// Push element onto the stack
push :: proc(s: ^$S/Stack($T), elem: T) -> (ok: bool, err: runtime.Allocator_Error) {
	if space(s^) == 0 {
		reserve(s, int(s.len) + 1) or_return
	}
	s.data[s.len] = elem
	s.len += 1
	return true, nil
}

// Push multiple elements onto the stack
push_elems :: proc(s: ^$S/Stack($T), elems: ..T) -> (ok: bool, err: runtime.Allocator_Error) {
	n := uint(len(elems))
	if space(s^) < int(n) {
		reserve(s, int(s.len) + int(n)) or_return
	}
	copy(s.data[s.len:], elems)
	s.len += n
	return true, nil
}

// Pop element from top of stack
pop :: proc(s: ^$S/Stack($T), loc := #caller_location) -> T {
	assert(s.len > 0, loc=loc)
	s.len -= 1
	return s.data[s.len]
}

// Safely pop element from top of stack
pop_safe :: proc(s: ^$S/Stack($T)) -> (elem: T, ok: bool) {
	if s.len > 0 {
		s.len -= 1
		elem = s.data[s.len]
		ok = true
	}
	return
}

// Clear stack contents
clear :: proc(s: ^$S/Stack($T)) {
	s.len = 0
}

// Aliases for push operations
append_elem  :: push
append_elems :: push_elems
append :: proc{push, push_elems}