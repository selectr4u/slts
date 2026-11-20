package main

import "core:fmt"
import "core:net"
import "core:os"
import "core:thread"
import "core:time"

Tcp_Server_Handler :: proc(client: net.TCP_Socket)

tcp_server_loop :: proc(sock: net.TCP_Socket, handler: Tcp_Server_Handler) {
	for {
		cli, _, err_accept := net.accept_tcp(sock)
		if err_accept != nil {
			fmt.printf("failed to accept tcp connection because: %s\n", err_accept)
			if (err_accept == .Interrupted || err_accept == .Invalid_Argument) {
				break
			}
			continue
		}
		handler(cli)
	}
	return
}

// forked off of https://pkg.odin-lang.org/examples/net/tcp_echo_server/server/#server.odin
start_tcp_server :: proc(
	ip: string,
	port: int,
	timeout: int,
	handler: Tcp_Server_Handler,
) -> (
	t: ^thread.Thread,
	socket: net.TCP_Socket,
	status: bool,
	err: string,
) {
	local_addr, ok := net.parse_ip4_address(ip)
	if !ok {
		return nil, {}, false, "failed to paerse IP address"
	}

	endpoint := net.Endpoint {
		address = local_addr,
		port    = port,
	}

	if (timeout > 0) {
		net.set_option(socket, .Receive_Timeout, time.Duration(timeout * int(time.Second)))
	}

	sock, err_listen := net.listen_tcp(endpoint)
	if err_listen != nil {
		return nil, {}, false, "failed to listen on tcp"
	}

	t = thread.create_and_start_with_poly_data2(sock, handler, tcp_server_loop)

	return t, sock, true, ""
}
