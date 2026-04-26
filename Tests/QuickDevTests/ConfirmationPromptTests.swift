import Testing
@testable import SwiftCLIKit

@Test func parseAcceptsYesNoAndDefaultNo() {
	#expect(ConfirmationPrompt.parse("y") == true)
	#expect(ConfirmationPrompt.parse("YES") == true)
	#expect(ConfirmationPrompt.parse(" n ") == false)
	#expect(ConfirmationPrompt.parse("") == false)
	#expect(ConfirmationPrompt.parse("maybe") == nil)
}

@Test func parseReturnsConfiguredDefaultForEmptyInput() {
	#expect(ConfirmationPrompt.parse("", defaultValue: true) == true)
}

@Test func askRetriesUntilItReceivesValidInput() {
	var responses = ["maybe", "YES"]
	var prompts: [String] = []

	let decision = ConfirmationPrompt.ask(
		prompt: "Proceed? [y/N]: ",
		inputReader: {
			guard responses.isEmpty == false else {
				return nil
			}

			return responses.removeFirst()
		},
		outputWriter: { prompts.append($0) }
	)

	#expect(decision == true)
	#expect(prompts == ["Proceed? [y/N]: ", "Please answer with Y or N: "])
}

@Test func askFallsBackToDefaultWhenInputEnds() {
	let decision = ConfirmationPrompt.ask(
		prompt: "Proceed? [Y/n]: ",
		defaultValue: true,
		inputReader: { nil },
		outputWriter: { _ in }
	)

	#expect(decision == true)
}
