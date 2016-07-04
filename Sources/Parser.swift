private enum ParserState {
	case starting
	case matchingTagName
	case matchingPropertyName
	case matchingPropertyValue
}

public final class Parser {
	private var openTagCount: Int = 0
	public var onFind: ((tag: String, value: [String: AnyObject]) -> Void)? = nil

	public init() {}

	public func parse(text: String) -> Bool {
		guard let onFind = onFind else {
			return false
		}

		var values = [String: AnyObject]()

		var currentTags = [String]()
		var currentProperty = ""

		var inString = false
		var ignoreNextCharacter = false
		var ignoringUntilClosingTag = false
		var stack = [Character]()
		var state: ParserState = .starting

		let matchedTagName = {
			state = .matchingPropertyName
			currentTags.append(String(stack))
			stack.removeAll()
		}

		let matchedKey = {
			state = .matchingPropertyValue
			currentProperty = String(stack)
			stack.removeAll()
		}

		let matchedValue = {
			state = .matchingPropertyName
			values[currentProperty] = String(stack) as AnyObject
			stack.removeAll()
		}

		for i in 0 ..< text.utf8.count {
			let character = text.characterAt(index: i)!
			if !inString && character == Character(">") {
				if state == .matchingTagName {
					matchedTagName()
				} else if state == .matchingPropertyValue {
					matchedValue()
				}

				state = .starting

				guard let currentTag = currentTags.popLast() else {
					return false
				}

				if ignoringUntilClosingTag && currentTag == "head" {
					return true
				}

				if !currentTag.isEmpty {
					onFind(tag: currentTag, value: values)
				}

				values.removeAll()
				currentProperty = ""

				ignoringUntilClosingTag = false
				openTagCount -= 1
				continue
			}

			if ignoringUntilClosingTag {
				continue
			}

			var didSetMatchingTagState = false
			if character == Character("<") {
				didSetMatchingTagState = true
				state = .matchingTagName
				openTagCount += 1
			}

			guard let nextCharacter = text.characterAt(index: i + 1) else {
				break
			}

			if !inString && nextCharacter == Character("/") {
				ignoringUntilClosingTag = true
				continue
			}

			if didSetMatchingTagState {
				continue
			}

			if state == .starting {
				continue
			}

			stack.append(character)

			if character == Character("\\") {
				if ignoreNextCharacter {
					ignoreNextCharacter = false
				} else {
					ignoreNextCharacter = true
					stack.removeLast()
					continue
				}
			} else {
				ignoreNextCharacter = false
			}

			if !ignoreNextCharacter && character == Character("\"") {
				stack.removeLast()

				if !inString {
					inString = true
					continue
				} else {
					inString = false
					continue
				}
			}

			if (character != Character(" ") && character != Character("=")) {
				continue
			}

			if state == .matchingTagName {
				stack.removeLast()
				matchedTagName()
				continue
			}

			if state == .matchingPropertyName {
				stack.removeLast()
				matchedKey()
				continue
			}

			if inString { continue }

			if state == .matchingPropertyValue {
				stack.removeLast()
				matchedValue()
				continue
			}
		}

		return openTagCount == 0
	}
}