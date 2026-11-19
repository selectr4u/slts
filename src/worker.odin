package main

import "core:fmt"
import "core:net"
import "core:sync/chan"
import "core:thread"
import lua "vendor:lua/5.5"

Worker_Task :: struct {
	socket: net.TCP_Socket,
}

Worker_Identifier :: struct {
	ls:     ^lua.State,
	id:     int,
	thread: ^thread.Thread,
}


worker_loop :: proc(ls: ^lua.State, recv_chan: chan.Chan(Worker_Task, .Recv), sh_ref: int) {
	for {
		task, ok := chan.recv(recv_chan)
		if !ok {
			break
		}
		// process request
		client := task.socket

		// get top
		top := lua.gettop(ls)

		// get the func
		lua.geti(ls, lua.REGISTRYINDEX, lua.Integer(sh_ref))

		// we want to pass this socket as a special table to Lua (metatable)
		sock := cast(^Socket)lua.newuserdata(ls, size_of(Socket))
		sock^ = Socket {
			socket = client,
			closed = false,
		}

		lua.L_setmetatable(ls, SOCKET_MT)

		// make sure all is called just fine!
		if (lua.pcall(ls, 1, 0, 0) != i32(lua.OK)) {
			err := lua.L_checkstring(ls, -1)
			lua.pop(ls, 1)
			lua.getglobal(ls, "_WID")
			worker_id := lua.tointeger(ls, -1)
			lua.pop(ls, 1)
			fmt.printf("[Worker %d] failed to call lua code: %s\n", worker_id, err)
			continue
		}

		// close...
		net.close(client)

		lua.settop(ls, top)
	}
}
