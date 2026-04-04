import Foundation

private func standardErrorProgressWriter(_ string: String) {
	guard let data = string.data(using: .utf8) else {
		return
	}

	FileHandle.standardError.write(data)
}

public struct ProgressBarStyle: Equatable, Sendable {
	public static let `default` = Self()

	public var barWidth: Int
	public var completeCharacter: Character
	public var incompleteCharacter: Character
	public var leftDelimiter: Character
	public var rightDelimiter: Character
	public var percentageWidth: Int
	public var includesCounts: Bool

	public init(
		barWidth: Int = 24,
		completeCharacter: Character = "#",
		incompleteCharacter: Character = "-",
		leftDelimiter: Character = "[",
		rightDelimiter: Character = "]",
		percentageWidth: Int = 3,
		includesCounts: Bool = true
	) {
		self.barWidth = max(1, barWidth)
		self.completeCharacter = completeCharacter
		self.incompleteCharacter = incompleteCharacter
		self.leftDelimiter = leftDelimiter
		self.rightDelimiter = rightDelimiter
		self.percentageWidth = max(0, percentageWidth)
		self.includesCounts = includesCounts
	}
}

public struct ProgressBarState: Equatable, Sendable {
	public var completedUnitCount: Int64
	public var totalUnitCount: Int64
	public var message: String?

	public init(
		completedUnitCount: Int64,
		totalUnitCount: Int64,
		message: String? = nil
	) {
		self.completedUnitCount = completedUnitCount
		self.totalUnitCount = totalUnitCount
		self.message = message
	}

	public var fractionCompleted: Double {
		guard totalUnitCount > 0 else {
			return 0
		}

		let clampedCompleted = min(max(completedUnitCount, 0), totalUnitCount)
		return Double(clampedCompleted) / Double(totalUnitCount)
	}
}

public struct ProgressBarRenderer: Sendable {
	public var style: ProgressBarStyle

	public init(style: ProgressBarStyle = .default) {
		self.style = style
	}

	public func render(_ state: ProgressBarState) -> String {
		let fraction = state.fractionCompleted
		let filledCount = min(style.barWidth, Int(fraction * Double(style.barWidth)))
		let emptyCount = max(0, style.barWidth - filledCount)
		let bar = String(style.leftDelimiter)
			+ String(repeating: String(style.completeCharacter), count: filledCount)
			+ String(repeating: String(style.incompleteCharacter), count: emptyCount)
			+ String(style.rightDelimiter)

		var segments: [String] = []

		if let message = state.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
			segments.append(message)
		}

		segments.append(bar)

		if style.percentageWidth > 0 {
			let percentage = Int((fraction * 100).rounded())
			segments.append(String(format: "%*d%%", style.percentageWidth, percentage))
		}

		if style.includesCounts {
			let completed = max(state.completedUnitCount, 0)
			let total = max(state.totalUnitCount, 0)
			segments.append("\(completed)/\(total)")
		}

		return segments.joined(separator: " ")
	}
}

public final class TerminalProgressBar {
	public typealias Writer = (String) -> Void

	public var renderer: ProgressBarRenderer

	private let writer: Writer
	private let lock = NSLock()
	private var lastRenderedLength = 0
	private var isFinished = false

	public init(
		style: ProgressBarStyle = .default,
		writer: Writer? = nil
	) {
		self.renderer = ProgressBarRenderer(style: style)
		self.writer = writer ?? standardErrorProgressWriter
	}

	public func update(_ state: ProgressBarState) {
		lock.lock()
		defer { lock.unlock() }

		guard !isFinished else {
			return
		}

		writeRenderedLine(renderer.render(state), includeNewline: false)
	}

	public func finish(with state: ProgressBarState? = nil) {
		lock.lock()
		defer { lock.unlock() }

		guard !isFinished else {
			return
		}

		if let state {
			writeRenderedLine(renderer.render(state), includeNewline: true)
		} else {
			writer("\n")
		}

		isFinished = true
		lastRenderedLength = 0
	}

	private func writeRenderedLine(_ line: String, includeNewline: Bool) {
		let paddingLength = max(0, lastRenderedLength - line.count)
		let padding = String(repeating: " ", count: paddingLength)
		let suffix = includeNewline ? "\n" : ""
		writer("\r\(line)\(padding)\(suffix)")
		lastRenderedLength = line.count
	}
}
