package main

import "core:os"
import "core:strings"
import lua "vendor:lua/5.5"

Config :: struct {
	host:         string,
	port:         u16,
	worker_count: int,
}

read_config :: proc(path: string) -> (cfg: Config, ok: bool, error: string) {
	// default values
	cfg = Config {
		host         = "127.0.0.1",
		port         = 8988,
		worker_count = 2,
	}

	// check existence first!
	if !os.exists(path) {
		return cfg, false, "path provided does not exist"
	}

	// open file w/ lua
	lua_state := lua.L_newstate()
	defer lua.close(lua_state)

	// make new cstr...
	cstr := strings.clone_to_cstring(path, context.temp_allocator)

	if (lua.L_dofile(lua_state, cstr) != i32(lua.OK)) {
		// indicates error
		err_msg := lua.tostring(lua_state, -1)
		lua.pop(lua_state, 1)
		return cfg, false, string(err_msg)
	}

	// check if table or not
	if !lua.istable(lua_state, -1) {
		lua.pop(lua_state, 1)
		return cfg, false, "expected table from config file"
	}

	// grab host
	lua.getfield(lua_state, -1, "host")
	if !lua.isnil(lua_state, -1) {
		host := lua.tostring(lua_state, -1)
		cfg.host = string(host)
	}

	lua.pop(lua_state, 1)

	// grab port
	lua.getfield(lua_state, -1, "port")
	if !lua.isnil(lua_state, -1) {
		port := lua.tonumber(lua_state, -1)
		cfg.port = u16(port)
	}

	lua.pop(lua_state, 1)

	// grab worker count
	lua.getfield(lua_state, -1, "worker_count")
	if !lua.isnil(lua_state, -1) {
		worker_count := lua.tonumber(lua_state, -1)
		if worker_count < 1 {
			// bit.. stupid to put less than 1 but JIC
			return cfg, false, "worker_count LESS than 1"
		}
		cfg.worker_count = int(worker_count)
	}

	lua.pop(lua_state, 2) // pops worker count AND the table

	return cfg, true, ""
}
