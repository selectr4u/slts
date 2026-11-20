package main

import "core:fmt"
import "core:net"
import "core:os"
import "core:strings"
import "core:sync/chan"
import "core:thread"
import "core:time"
import lua "vendor:lua/5.5"

task_chan: chan.Chan(Worker_Task)


main :: proc() {
	// --grab cmd args--
	args := os.args

	if (len(args) < 2) {
		fmt.println("lua file to run not provided!")
		return
	}

	// --get config.lua & read (expected to be in same cwd)--
	cfg, ok, err := read_config("config.lua")
	if (!ok) {
		fmt.printf("error when trying to read config.lua: %s\n", err)
		return
	}

	// --create channel--
	c, chan_err := chan.create(chan.Chan(Worker_Task), 128, context.allocator) // channel holds up to 128 tasks
	if chan_err != .None {
		fmt.println("could not open channel for workers to receive requests")
		return
	}
	task_chan = c // put in global

	defer chan.destroy(c)

	// --create workers-- + --load inputted lua file & make sure it is what we expect--
	workers := make([dynamic]Worker_Identifier, cfg.worker_count)
	defer delete(workers)

	for i in 0 ..= (cfg.worker_count - 1) {
		// setup lua state
		ls := lua.L_newstate()

		// also additionally push a _WID BEFORE setup
		lua.pushinteger(ls, lua.Integer(i))
		lua.setglobal(ls, "_WID")

		sh_ref, ok, err := setup_lua_vm(ls, args[1])
		if !ok {
			fmt.printf("lua vm could not be setup: %s", err)
			panic("failed to set up lua_vm")
		}

		// setup thread
		t := thread.create_and_start_with_poly_data3(
			ls,
			chan.as_recv(task_chan),
			int(sh_ref),
			worker_loop,
		)

		wk := Worker_Identifier {
			id     = i + 1,
			ls     = ls,
			thread = t,
		}
		workers[i] = wk
		fmt.printf("Created worker %d\n", wk.id)
	}

	defer {
		for i in 0 ..= (cfg.worker_count - 1) {
			wk := workers[i]
			thread.join(wk.thread)
			lua.close(wk.ls)
			fmt.printf("Closed worker %d\n", wk.id)
		}
	}

	// --create tcp socket--
	server_thread, socket, sts_ok, sts_err := start_tcp_server(
	cfg.host,
	int(cfg.port),
	cfg.timeout,
	proc(client: net.TCP_Socket) {
		// send to channel
		wt := Worker_Task {
			socket = client,
		}
		assert(chan.send(task_chan, wt))
	},
	)

	if !sts_ok {
		fmt.printf("could not start tcp server: %s\n", sts_err)
		return
	}

	fmt.printf("started tcp server on: %s:%d\n", cfg.host, cfg.port)

	defer {
		net.close(socket)
		thread.join(server_thread)
	}

	// --listen for q being entered--
	fmt.println("To quit, enter q and press enter")
	for {
		buf: [256]u8
		n, err := os.read(os.stdin, buf[:])
		if err != nil || n == 0 {
			fmt.eprintf("error reading: %s\n", err)
			break
		}

		str := string(buf[:n])
		if strings.compare("q", strings.trim_space(str)) == 0 {
			break
		}
	}

	chan.close(task_chan)
	return
}
