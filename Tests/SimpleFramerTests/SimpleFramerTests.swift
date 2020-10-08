import XCTest
@testable import SimpleFramer

import Network

let clientQueue = DispatchQueue(label: "Server")
let serverQueue = DispatchQueue(label: "Client")

final class SimpleFramerTests: XCTestCase {

    func testChunkedInTheMiddle() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
		var firstMessages = Set(messages[0...2])
		let splitMessage = messages[3]
		let lastMessage = messages.last!

		let receiveFirstThreeMessages = XCTestExpectation(description: "Receive first three messages")
		let receiveSplitMessage = XCTestExpectation(description: "Receive split message")
		let receiveLastMessage = XCTestExpectation(description: "Receive last message")

		let server = try! NWListener(using: .tcp)
		server.newConnectionHandler = sendChunks

		server.stateUpdateHandler = { state in
			print("🖲 server:", state)
			if state == .ready, let port = server.port {
				print("🖲 server: listening on", port)
			}
		}

		server.start(queue: serverQueue)

		let networkParameters = NWParameters.tcp
		networkParameters
			.defaultProtocolStack
			.applicationProtocols
			.insert(
				NWProtocolFramer.Options(definition: PipeFramer.definition),
				at: 0
			)
		let client = NWConnection(to: .hostPort(host: "localhost", port: server.port!), using: networkParameters)

		func receiveNext() {
			client.receiveMessage { (data, context, complete, error) in
				let content: String
				if let data = data {
					if let string = String(data: data, encoding: .utf8) {
						content = string
						firstMessages.remove(content)
					} else {
						content = data.description
					}
				} else {
					content = "<no data>"
					if error == nil && complete {
						firstMessages.remove("")
					}
				}
				print("👨‍💻 client: received \"\(content)\"", context.debugDescription, complete, error?.localizedDescription ?? "No error")
				if firstMessages.isEmpty { receiveFirstThreeMessages.fulfill() }
				if content == splitMessage { receiveSplitMessage.fulfill() }
				if content == lastMessage { receiveLastMessage.fulfill() }

				receiveNext()
			}
		}

		client.stateUpdateHandler = { state in
			print("👨‍💻 client:", state)

			if state == .ready {
				print("👨‍💻 client: receiving")
				receiveNext()
			}
		}

		client.start(queue: clientQueue)

		wait(for: [receiveFirstThreeMessages, receiveSplitMessage, receiveLastMessage], timeout: 6)
    }

    static var allTests = [
        ("testChunkedInTheMiddle", testChunkedInTheMiddle),
    ]
}

let messages = ["A", "Be", "", "Split in the middle", "0", "Done"]

func sendChunks(to connection: NWConnection) {
	let delimitedMessages = messages.joined(separator: "|")
	let chunk0End = delimitedMessages.range(of: " t")!.lowerBound
	let chunk1End = delimitedMessages.range(of: "0|")!.lowerBound
	let firstChunk = delimitedMessages.prefix(upTo: chunk0End)
	let secondChunk = delimitedMessages[chunk0End..<chunk1End]
	let thirdChunk = delimitedMessages[chunk1End...]

	print("🖲 server: new connection from", connection.endpoint)

	func send(string: Substring, isComplete: Bool = true) {
		print("🖲 server: sending \"\(string)\" 🖲")
		connection.send(content: string.data(using: .utf8)!, isComplete: isComplete, completion: .idempotent)
	}
	func reportClientState() {
		print("🖲 server (client \(connection.endpoint)): state", connection.state)
	}

	reportClientState()

	connection.viabilityUpdateHandler = { viable in
		reportClientState()
		if viable {
			print("🖲 server: sending")
			send(string: firstChunk, isComplete: false)

			serverQueue.asyncAfter(deadline: .now() + 2) {
				send(string: secondChunk)
			}
			serverQueue.asyncAfter(deadline: .now() + 4) {
				send(string: thirdChunk)
			}
		}
	}

	connection.start(queue: serverQueue)
}
