import SwiftUI

/// Renders a markdown-formatted string inside a chat bubble.
///
/// Supports common markdown elements from AI responses:
/// - **Bold** (`**text**` or `__text__`)
/// - *Italic* (`*text*` or `_text_`)
/// - Bullet lists (`- item` or `• item`)
/// - Numbered lists (`1. item`)
/// - Inline code (`` `code` ``)
/// - Headers (`# heading`, `## heading`, `### heading`)
///
/// Uses iOS 15+ `AttributedString` with markdown parsing, falling back to a
/// custom regex-based parser for elements that `AttributedString` doesn't handle
/// (like bullet lists being rendered as plain text).
struct MarkdownTextView: View {

    let content: String
    let foregroundColor: Color
    let isUser: Bool

    init(_ content: String, foregroundColor: Color = .primary, isUser: Bool = false) {
        self.content = content
        self.foregroundColor = foregroundColor
        self.isUser = isUser
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parsedBlocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Types

    private enum MarkdownBlock {
        case paragraph(String)
        case bulletItem(String)
        case numberedItem(number: String, text: String)
        case heading(level: Int, text: String)
        case codeBlock(String)
        case empty
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            inlineMarkdownText(text)

        case .bulletItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(foregroundColor.opacity(0.6))
                inlineMarkdownText(text)
            }
            .padding(.leading, 4)

        case .numberedItem(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(foregroundColor.opacity(0.6))
                    .frame(width: 18, alignment: .trailing)
                inlineMarkdownText(text)
            }
            .padding(.leading, 2)

        case .heading(_, let text):
            Text(text)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(foregroundColor)
                .padding(.top, 4)

        case .codeBlock(let code):
            Text(code)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(foregroundColor.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isUser ? Color.white.opacity(0.12) : Color.primary.opacity(0.06))
                )

        case .empty:
            Spacer().frame(height: 4)
        }
    }

    // MARK: - Inline Markdown (bold, italic, code)

    private func inlineMarkdownText(_ text: String) -> Text {
        // Try iOS 15+ AttributedString first for inline formatting
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(applyColors(attributed))
        }
        // Fallback: plain text
        return Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(foregroundColor)
    }

    /// Re-applies our desired foreground color to an AttributedString since
    /// `AttributedString(markdown:)` defaults to system label color.
    private func applyColors(_ source: AttributedString) -> AttributedString {
        var result = source
        result.font = .system(size: 15, weight: .medium)
        result.foregroundColor = foregroundColor

        // Make bold runs actually bold
        for run in result.runs {
            let range = run.range
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.stronglyEmphasized) {
                    result[range].font = .system(size: 15, weight: .bold)
                }
                if intent.contains(.code) {
                    result[range].font = .system(size: 13, weight: .medium, design: .monospaced)
                    result[range].backgroundColor = isUser
                        ? Color.white.opacity(0.12)
                        : Color.primary.opacity(0.08)
                }
            }
        }
        return result
    }

    // MARK: - Block-Level Parsing

    /// Splits the markdown string into structured blocks for rendering.
    private var parsedBlocks: [MarkdownBlock] {
        let lines = content.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraphBuffer: [String] = []
        var inCodeBlock = false
        var codeBuffer: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block fences
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(.codeBlock(codeBuffer.joined(separator: "\n")))
                    codeBuffer = []
                    inCodeBlock = false
                } else {
                    flushParagraph(&paragraphBuffer, into: &blocks)
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBuffer.append(line)
                continue
            }

            // Empty line
            if trimmed.isEmpty {
                flushParagraph(&paragraphBuffer, into: &blocks)
                blocks.append(.empty)
                continue
            }

            // Heading
            if let headingMatch = trimmed.headingMatch() {
                flushParagraph(&paragraphBuffer, into: &blocks)
                blocks.append(.heading(level: headingMatch.level, text: headingMatch.text))
                continue
            }

            // Bullet list
            if let bulletText = trimmed.bulletText() {
                flushParagraph(&paragraphBuffer, into: &blocks)
                blocks.append(.bulletItem(bulletText))
                continue
            }

            // Numbered list
            if let (num, text) = trimmed.numberedListMatch() {
                flushParagraph(&paragraphBuffer, into: &blocks)
                blocks.append(.numberedItem(number: num, text: text))
                continue
            }

            // Regular text — accumulate into paragraph
            paragraphBuffer.append(trimmed)
        }

        // Flush remaining
        if inCodeBlock && !codeBuffer.isEmpty {
            blocks.append(.codeBlock(codeBuffer.joined(separator: "\n")))
        }
        flushParagraph(&paragraphBuffer, into: &blocks)

        // Remove trailing empty blocks
        while blocks.last.map({ if case .empty = $0 { return true } else { return false } }) == true {
            blocks.removeLast()
        }

        return blocks
    }

    private func flushParagraph(_ buffer: inout [String], into blocks: inout [MarkdownBlock]) {
        guard !buffer.isEmpty else { return }
        blocks.append(.paragraph(buffer.joined(separator: " ")))
        buffer = []
    }
}

// MARK: - String Helpers for Markdown Parsing

private extension String {

    func bulletText() -> String? {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") {
            return String(trimmed.dropFirst(2))
        }
        if trimmed.hasPrefix("• ") {
            return String(trimmed.dropFirst(2))
        }
        if trimmed.hasPrefix("* ") && !trimmed.hasPrefix("**") {
            return String(trimmed.dropFirst(2))
        }
        return nil
    }

    func numberedListMatch() -> (String, String)? {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let numberPart = String(trimmed[trimmed.startIndex..<dotIndex])
        guard numberPart.allSatisfy({ $0.isNumber }), !numberPart.isEmpty else { return nil }
        let afterDot = trimmed[trimmed.index(after: dotIndex)...]
        guard afterDot.first == " " else { return nil }
        let text = String(afterDot.dropFirst()).trimmingCharacters(in: .whitespaces)
        return (numberPart, text)
    }

    struct HeadingMatch {
        let level: Int
        let text: String
    }

    func headingMatch() -> HeadingMatch? {
        let trimmed = self.trimmingCharacters(in: .whitespaces)
        var level = 0
        for c in trimmed {
            if c == "#" { level += 1 } else { break }
        }
        guard level >= 1 && level <= 3 else { return nil }
        let after = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        guard !after.isEmpty else { return nil }
        return HeadingMatch(level: level, text: after)
    }
}

// MARK: - Preview

#if DEBUG
struct MarkdownTextView_Previews: PreviewProvider {
    static let sampleMarkdown = """
    Here's your workout plan:

    **Morning Routine:**
    1. Start with **jumping jacks** for warm-up
    2. Do 3 sets of *squats*
    3. Finish with `10 min` stretching

    ### Tips
    - Keep your back straight
    - Breathe steadily
    - Stay hydrated 💧

    Great job staying consistent! Your **5-day streak** is impressive.
    """

    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
            MarkdownTextView(sampleMarkdown, foregroundColor: .primary, isUser: false)
                .padding(14)
                .background(Color(.systemGray6))
                .cornerRadius(12)

            MarkdownTextView("Let me try **arm raises** today!", foregroundColor: .black, isUser: true)
                .padding(14)
                .background(Color.orange)
                .cornerRadius(12)
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}
#endif
