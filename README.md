# How to write a NWProtocolFramer for Network.framework that splits streams into frames using a delimiter?

I tried to create a framer that splits a stream of ASCII bytes into frames separated by the pipe ascii character: `"|"`. This framer is located in [/Sources/SimpleFramer/SimpleFramer.swift](/Sources/SimpleFramer/SimpleFramer.swift)

The problem is that from the moment I get a chunk that does not end with `"|"`, the framer gets stuck on that chunk. So the other chunks that come after this incomplete chunk never fully arrive in the `framer.parseInput(...)` call. Because it always parses chunks of `minimumIncompleteLength` and hence never arrives to the point where the next `"|"` is.

Here is a simple reproduction of this problem:

 1. Create a TCP server
 2. Setup the server so that it sends chunks of messages when a client connects.
 3. Connect to the server (created in 1.) using the framer from above.
 4. Start receiving messages.

The code for this reproduction is located in [/Tests/SimpleFramerTests/SimpleFramerTests.swift](/Tests/SimpleFramerTests/SimpleFramerTests.swift) and can be run using the following command in the terminal

```shell
swift test
```

And produces the following console output:

```
🖲 server: waiting(POSIXErrorCode: Network is down)
🖲 server: ready
🖲 server: listening on 54907
👨‍💻 client: preparing
👨‍💻 client: ready
👨‍💻 client: receiving
🖲 server: new connection from ::1.52957
🖲 server (client ::1.52957): state setup
🖲 server (client ::1.52957): state ready
🖲 server: sending
🖲 server: sending "A|Be||Split in" 🖲
👨‍💻 client: handle input
👨‍💻 client:		parsing buffer: "A|Be||Split in"
👨‍💻 client:		minLength set to 1
👨‍💻 client:		parsing buffer: "Be||Split in"
👨‍💻 client:		minLength set to 1
👨‍💻 client:		parsing buffer: "|Split in"
👨‍💻 client:		minLength set to 1
👨‍💻 client:		parsing buffer: "Split in"
👨‍💻 client:		minLength set to 9
👨‍💻 client: handle input
👨‍💻 client:		parsing buffer: ""
👨‍💻 client:		minLength set to 1
👨‍💻 client: received "A" Optional(Network.NWConnection.ContentContext) true No error
👨‍💻 client: received "Be" Optional(Network.NWConnection.ContentContext) true No error
👨‍💻 client: received "<no data>" Optional(Network.NWConnection.ContentContext) true No error
👨‍💻 client: handle input
👨‍💻 client:		parsing buffer: "Split in"
👨‍💻 client:		minLength set to 9
🖲 server: sending " the middle|" 🖲
👨‍💻 client: handle input
👨‍💻 client:		parsing buffer: "Split in "
👨‍💻 client:		minLength set to 10
👨‍💻 client: handle input
👨‍💻 client:		parsing buffer: "Split in t"
👨‍💻 client:		minLength set to 11
🖲 server: sending "0|Done" 🖲
👨‍💻 client: handle input
👨‍💻 client:		parsing buffer: "Split in th"
👨‍💻 client:		minLength set to 12
👨‍💻 client: handle input
👨‍💻 client:		parsing buffer: "Split in the"
👨‍💻 client:		minLength set to 13
```
