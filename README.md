# slts

slts (simple lua tcp server) is a _very basic_ way of serving a TCP server in lua. It is written in Odin, and has a config.lua file that can be used to specify worker_amount (threads), port, and host. It also requires a lua file to be passed via the command line.

# Compiling

You can build and run it, simply do

```
odin run src -- test.lua
```

or... the more better way is to build first, and get an executable is to do

```
odin build src -out:out/slts
```

obviously... make sure the `out` folder does exist.

*for gracefulness, I have included the binary compiled on my mac mini m4 (so arm-based and macos) which is located in `out/`

# Usage

## Configuring

slts requires in its working directory to have a config.lua file specifically.
For example, for 10 workers a config.lua file would look like:

```lua
return {
    worker_amount = 10
}
```

For a change in port, we can do:

```lua
return {
    worker_amount = 10
    port = 9480
}
```

You must have a `config.lua` file, even if you want the default configuration, and it must return a table. The defaults are very random:

```lua
return {
	host         = "127.0.0.1",
	port         = 8988,
	worker_count = 2,
}
```

## Running

Then, we will want a main entry point file which should return a function.
For example, the file I used to _briefly_ test it was `test.lua` which looked like:

```lua
local worker_id = _WID

return function(socket)
    print("received data!")
    local br, data = socket:recv(512)
    print(br) -- bytes received
    print("-----")
    print(data)
    print("-----")

    -- bw is bytes wrote
    local bw = socket:send(
        "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 63\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n500 Internal Server Error - Worker handling your request failed")
    print(bw)

    socket:close() -- explicit socket:close() [not necessarily required]
end
```

It is _very_ simple and also primitive.

To run, we can do

```
slts test.lua
```

You will also get alot of information in your stdout. Additionally, to gracefully quit, it is recommended you type `q` then `enter` (it will inform you of this in the terminal).

You can `ctrl+c` but that is up to you.

# Why?

I wanted to try out Odin basically and try and build a project of my that I planned out ages ago. However, I only built a very stripped down part of that project (the TCP server). I quite liked Odin.
