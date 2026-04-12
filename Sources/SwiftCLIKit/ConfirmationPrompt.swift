import Foundation

public enum ConfirmationPrompt {
	public typealias InputReader = () -> String?
	public typealias OutputWriter = (String) -> Void

	/// Parses a yes/no response for interactive terminal prompts.
	/// - Parameters:
	///   - response: Raw input entered by the user.
	///   - defaultValue: Value returned when the response is empty or input ends.
	/// - Returns: `true` for yes, `false` for no, or `nil` when the response is not recognized.
	public static func parse(_ response: String, defaultValue: Bool = false) -> Bool? {
		let normalized = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

		guard normalized.isEmpty == false else {
			return defaultValue
		}

		switch normalized {
		case "y", "yes":
			return true
		case "n", "no":
			return false
		default:
			return nil
		}
	}

	/// Repeatedly prompts for a yes/no decision until input is valid or the input stream ends.
	/// - Parameters:
	///   - prompt: Prompt text written before reading input. Include any trailing separator.
	///   - invalidResponsePrompt: Prompt text written after an invalid response.
	///   - defaultValue: Value returned when the user submits an empty response or input ends.
	///   - inputReader: Input source used to read terminal lines.
	///   - outputWriter: Output sink used to render prompt text.
	/// - Returns: The confirmed yes/no decision.
	@discardableResult
	public static func ask(
		prompt: String,
		invalidResponsePrompt: String = "Please answer with Y or N: ",
		defaultValue: Bool = false,
		inputReader: InputReader = { readLine(strippingNewline: true) },
		outputWriter: OutputWriter? = nil
	) -> Bool {
		let outputWriter = outputWriter ?? { string in
			guard let data = string.data(using: .utf8) else {
				return
			}

			FileHandle.standardOutput.write(data)
		}
		outputWriter(prompt)

		while let response = inputReader() {
			if let decision = parse(response, defaultValue: defaultValue) {
				return decision
			}

			outputWriter(invalidResponsePrompt)
		}

		return defaultValue
	}
}
