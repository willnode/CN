# UDS - Stream

Last update: Feb 2026

I'm just jumping straight here because this component is absolute must to get X11 and D-Bus working. Ibuki RSoC that bring this to live is invaluable and correctly done, he even wrote extensive test to it in acid repo, and I feel the code is quite modular.

This was brought to be point that X11 working, to the point that Mate Desktop is working. However it's reported that the progress stuck when D-Bus is added. So I wrote it as I try to solve it.

## The Grand of Scheme

UDS Stream is akin to inet TCP:

1. Listener: `socket()` -> `bind()` -> `accept()` -> `read()`/`write()`
2. Client: `socket()` -> `connect()` -> `read()`/`write()`

Note that POSIX defines `listen()` which should be called after bind and before accept, but in Redox OS this is a no-op (relibc won't send anything to service) so there's just three step here. 

I'm going straight explaining the code in `base/ipcd/src/uds/stream.rs`

## Socket() call

This is straightforward, just an opaque socket file id, nothing specific to UDS except calling `handle_unnamed_socket()` with `State::Unbound`.

As sockets can be `dup`, there's `primary_id` as the canon FD (file descriptor) number.

## Bind() call -> `SocketCall::Bound`

This set socket state to `State::Bound`. Immediate error if it was not `State::Unbound`. Also set `socket.path` and `socket.issued_token`. 

Weird part is since there's no `listen()`, this call also implicitly call `socket.start_listening()`, which set socket state to `State::Listening`, nothing else.

## Connect() call -> `SocketCall::Connect`

This is where it start get ugly, be prepare to remember which one is `listener` and `client`. The one who call this is `client`, connecting to `listener`.

This does couple of state check, but the point is, it's pushing `awaiting` to listener queue with client `primary_id`, set client socket to `State::Connecting`, and assign listener `primary_id` to client `connection.peer`.

## Accept() call -> `"listen"` dup

This call is done via `dup`, because it copies the fd, unlike `connect()` which is just used once:

```c
// you would use accepted_fd to perform read write
int accepted_fd = accept(server_fd, NULL, NULL);
```

As such, this call expect `OpenResult`, handled by `accepted_fd`, looping over `awaited` to get the one that's ready to be accepted. If there's nothing ready, it will return `EAGAIN` or `EWOULDBLOCK`. `EWOULDBLOCK` will hang the caller until it's available.

In listener socket, it call `socket.accept()`, which creates another socket with new `primary_id`, state as `State::Established`, `connection` as the fd from current `awaiting`.

In the client socket it call `socket.establish()`, the state is set as `State::Accepted`, doing extra check if `connection.peer` still the same as old `primary_id`, then set it as that new `primary_id`.

## So what happen if connection establishes?

you got two fd to communicate, one is `client_fd` and `accepted_fd`:

+ `client_fd.state` = `State::Accepted`
+ `client_fd.connection.peer` = `accepted_fd`
+ `accepted_fd.state` = `State::Established`
+ `accepted_fd.connection.peer` = `client_fd`

## Write() call

All write() has to do is just push the data into `accepted_fd.connection.packets`, which `accepted_fd` is come from `client_fd.connection.peer`.

You'll think this is straightforward, but `write()` can not fail even before the listener call `accept()`. How do you do it while `client_fd.connection.peer` refers to it's old id?

Well, during `accept()`, all `client_fd.connection.packets` will be moved to `accepted_fd.connection.packets`. So the listener can see the packets straight away.

## Read() call

All read() does is just reading the buffer from `self.connection.packets`, or return `EAGAIN` or `EWOULDBLOCK`. `EWOULDBLOCK` will hang the caller until it's available.
