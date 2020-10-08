import Network

class PipeFramer: NWProtocolFramerImplementation {
	static let label = "Pipe framer"
	static let definition = NWProtocolFramer.Definition(implementation: PipeFramer.self)
	static let delimiter = Character("|").asciiValue!

	var minLengthUntilNextMessage = 1 {
		didSet { print("👨‍💻 client:\t\tminLength set to", minLengthUntilNextMessage) }
	}

	required init(framer: NWProtocolFramer.Instance) {}

	func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }

	func handleInput(framer: NWProtocolFramer.Instance) -> Int {
		print("👨‍💻 client: handle input")
		while true {
			var delimiterPosition: Int?
			_ = framer.parseInput(minimumIncompleteLength: minLengthUntilNextMessage, maximumLength: 65535) { buffer, endOfMessage in
				if let buffer = buffer {
					print("👨‍💻 client:\t\tparsing buffer: \"\(String(bytes: buffer, encoding: .utf8) ?? buffer.debugDescription)\"")
					if let indexOfDelimiter = buffer.firstIndex(of: Self.delimiter) {
						minLengthUntilNextMessage = 1
						delimiterPosition = indexOfDelimiter
					} else {
						minLengthUntilNextMessage = buffer.count + 1
					}
				} else {
					print("👨‍💻 client:\t\tno buffer")
				}
				return 0
			}

			if let length = delimiterPosition {
				guard framer.deliverInputNoCopy(length: length, message: .init(instance: framer), isComplete: true) else {
					return 0
				}
				_ = framer.parseInput(minimumIncompleteLength: 1, maximumLength: 65535) { _,_ in 1 }
			} else {
				return minLengthUntilNextMessage
			}
		}
	}

	func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
		try! framer.writeOutputNoCopy(length: messageLength)
		framer.writeOutput(data: [Self.delimiter])
	}

	func wakeup(framer: NWProtocolFramer.Instance) {}

	func stop(framer: NWProtocolFramer.Instance) -> Bool { return true }

	func cleanup(framer: NWProtocolFramer.Instance) { }
}

