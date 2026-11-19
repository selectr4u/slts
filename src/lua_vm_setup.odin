package main

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:net"
import "core:strings"
import lua "vendor:lua/5.5"

Socket :: struct {
	socket: net.TCP_Socket,
	closed: bool,
}

SOCKET_MT :: "slts.Socket"

socket_close :: proc "c" (ls: ^lua.State) -> i32 {
	sock := cast(^Socket)lua.L_checkudata(ls, 1, SOCKET_MT)

	if !sock.closed {
		context = runtime.default_context()
		net.close(sock.socket)
		sock.closed = true
	}

	return 0
}

socket_recv :: proc "c" (ls: ^lua.State) -> i32 {
	context = runtime.default_context()
	sock := cast(^Socket)lua.L_checkudata(ls, 1, SOCKET_MT)

	if sock.closed {
		lua.L_error(ls, "socket is closed")
		return 0
	}

	max_bytes := lua.L_checkinteger(ls, 2)

	buffer := make([dynamic]u8, max_bytes)
	bytes_recv, err_recv := net.recv_tcp(sock.socket, buffer[:])
	if err_recv != nil {
		lua.L_error(ls, "failed to receive data")
		return 0
	}
	received := buffer[:bytes_recv]

	// push our bytes received
	lua.pushinteger(ls, lua.Integer(bytes_recv))
	// then our buffer
	lua.pushlstring(ls, cast(cstring)raw_data(buffer), uint(bytes_recv))
	return 2
}

socket_send :: proc "c" (ls: ^lua.State) -> i32 {
	context = runtime.default_context()
	sock := cast(^Socket)lua.L_checkudata(ls, 1, SOCKET_MT)

	if sock.closed {
		lua.L_error(ls, "socket is closed")
		return 0
	}

	length: c.size_t
	data := lua.L_checkstring(ls, 2, &length)

	buffer := make([dynamic]u8, length)
	defer delete(buffer)

	copy(buffer[:], string(data))
	// we then send length bytes from data using sock.fd
	bytes_written, err := net.send_tcp(sock.socket, buffer[:])
	if err != .None {
		lua.L_error(ls, "could not send data to socket")
		return 0
	}

	lua.pushinteger(ls, lua.Integer(bytes_written))
	return 1
}

socket_gc :: proc "c" (ls: ^lua.State) -> i32 {
	return socket_close(ls)
}


register_socket_type :: proc(ls: ^lua.State) {
	lua.L_newmetatable(ls, SOCKET_MT)

	// push the garbage collection function
	lua.pushcfunction(ls, socket_gc)
	lua.setfield(ls, -2, "__gc")

	// set mt index
	lua.pushvalue(ls, -1)
	lua.setfield(ls, -2, "__index")

	// push all other functions
	lua.pushcfunction(ls, socket_close)
	lua.setfield(ls, -2, "close")

	lua.pushcfunction(ls, socket_recv)
	lua.setfield(ls, -2, "recv")

	lua.pushcfunction(ls, socket_send)
	lua.setfield(ls, -2, "send")

	lua.pop(ls, 1)
}

// helper to setup our lua vm
setup_lua_vm :: proc(
	ls: ^lua.State,
	init_file: string,
) -> (
	socket_handler_ref: int,
	ok: bool,
	err: string,
) {
	lua.open_base(ls)
	lua.L_openlibs(ls)

	cstr := strings.clone_to_cstring(init_file, context.temp_allocator)
	if (lua.L_dofile(ls, cstr) != i32(lua.OK)) {
		err_msg := lua.L_checkstring(ls, -1)
		return 0, false, string(err_msg)
	}

	if (!lua.isfunction(ls, -1)) {
		return 0, false, "expected function to be returned in lua file"
	}

	sh_ref := lua.L_ref(ls, lua.REGISTRYINDEX)

	// also register socket type as a custom type
	register_socket_type(ls)

	return int(sh_ref), true, ""
}
