//
//  ContentView.swift
//  calculator
//

import SwiftUI
import UIKit

// MARK: - Theme

struct CalculatorTheme: Identifiable {
    let id: Int
    let name: String
    let emoji: String
    let background: Color
    let displaySecondary: Color
    let numberDefault: Color
    let numberPressed: Color
    let functionDefault: Color
    let functionPressed: Color
    let operationDefault: Color
    let operationPressed: Color
    let foreground: Color
}

extension CalculatorTheme {
    static let all: [CalculatorTheme] = [dark, light, ocean, rose, mint]

    static let dark = CalculatorTheme(
        id: 0, name: "Dark", emoji: "🌑",
        background:       Color(red: 0.09, green: 0.07, blue: 0.05),
        displaySecondary: Color(red: 0.62, green: 0.58, blue: 0.53),
        numberDefault:    Color(red: 0.22, green: 0.18, blue: 0.13),
        numberPressed:    Color(red: 0.31, green: 0.27, blue: 0.22),
        functionDefault:  Color(red: 0.38, green: 0.33, blue: 0.26),
        functionPressed:  Color(red: 0.50, green: 0.44, blue: 0.36),
        operationDefault: Color(red: 1.00, green: 0.66, blue: 0.00),
        operationPressed: Color(red: 1.00, green: 0.80, blue: 0.33),
        foreground: .white
    )
    static let light = CalculatorTheme(
        id: 1, name: "Light", emoji: "☀️",
        background:       Color(red: 0.94, green: 0.92, blue: 0.88),
        displaySecondary: Color(red: 0.45, green: 0.42, blue: 0.38),
        numberDefault:    Color(red: 0.84, green: 0.81, blue: 0.76),
        numberPressed:    Color(red: 0.74, green: 0.70, blue: 0.64),
        functionDefault:  Color(red: 0.68, green: 0.63, blue: 0.57),
        functionPressed:  Color(red: 0.58, green: 0.53, blue: 0.47),
        operationDefault: Color(red: 1.00, green: 0.58, blue: 0.00),
        operationPressed: Color(red: 1.00, green: 0.72, blue: 0.28),
        foreground: Color(red: 0.12, green: 0.09, blue: 0.06)
    )
    static let ocean = CalculatorTheme(
        id: 2, name: "Ocean", emoji: "🌊",
        background:       Color(red: 0.04, green: 0.10, blue: 0.18),
        displaySecondary: Color(red: 0.45, green: 0.65, blue: 0.85),
        numberDefault:    Color(red: 0.08, green: 0.18, blue: 0.30),
        numberPressed:    Color(red: 0.12, green: 0.25, blue: 0.40),
        functionDefault:  Color(red: 0.10, green: 0.28, blue: 0.45),
        functionPressed:  Color(red: 0.14, green: 0.36, blue: 0.55),
        operationDefault: Color(red: 0.00, green: 0.65, blue: 0.85),
        operationPressed: Color(red: 0.20, green: 0.78, blue: 0.95),
        foreground: .white
    )
    static let rose = CalculatorTheme(
        id: 3, name: "Rose", emoji: "🌸",
        background:       Color(red: 0.10, green: 0.04, blue: 0.06),
        displaySecondary: Color(red: 0.85, green: 0.55, blue: 0.65),
        numberDefault:    Color(red: 0.22, green: 0.10, blue: 0.14),
        numberPressed:    Color(red: 0.30, green: 0.16, blue: 0.20),
        functionDefault:  Color(red: 0.35, green: 0.14, blue: 0.20),
        functionPressed:  Color(red: 0.45, green: 0.20, blue: 0.28),
        operationDefault: Color(red: 0.90, green: 0.30, blue: 0.50),
        operationPressed: Color(red: 1.00, green: 0.50, blue: 0.65),
        foreground: .white
    )
    static let mint = CalculatorTheme(
        id: 4, name: "Mint", emoji: "🌿",
        background:       Color(red: 0.04, green: 0.12, blue: 0.10),
        displaySecondary: Color(red: 0.45, green: 0.80, blue: 0.68),
        numberDefault:    Color(red: 0.08, green: 0.22, blue: 0.18),
        numberPressed:    Color(red: 0.12, green: 0.30, blue: 0.25),
        functionDefault:  Color(red: 0.10, green: 0.30, blue: 0.24),
        functionPressed:  Color(red: 0.16, green: 0.40, blue: 0.32),
        operationDefault: Color(red: 0.10, green: 0.78, blue: 0.58),
        operationPressed: Color(red: 0.30, green: 0.90, blue: 0.70),
        foreground: .white
    )
}

// MARK: - Button Shape

enum ButtonShape: CaseIterable { case circle, rounded }

// MARK: - History Entry

struct HistoryEntry: Identifiable {
    let id = UUID()
    let expression: String  // e.g. "12 + 8"
    let result: String      // e.g. "20"
}

// MARK: - Content View

struct ContentView: View {

    // Calculator state
    @State private var currentInput: String = "0"
    @State private var previousInput: String = ""
    @State private var pendingOp: CalcOperation? = nil
    @State private var shouldClearInput: Bool = false
    @State private var justCalculated: Bool = false   // true right after "=" pressed

    // History
    @State private var history: [HistoryEntry] = []
    @State private var showHistory: Bool = false

    // UI
    @State private var themeIndex: Int = 0
    @State private var buttonShape: ButtonShape = .circle
    @State private var showSettings: Bool = false

    // Haptics
    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticError  = UINotificationFeedbackGenerator()

    private var theme: CalculatorTheme { CalculatorTheme.all[themeIndex] }

    enum CalcOperation { case add, subtract, multiply, divide }

    // MARK: - Display logic
    //
    // Line 1 (secondary / small):
    //   • Idle or just typed a number         → empty
    //   • After operator pressed              → "\(prev) \(op)"   e.g. "12 +"
    //   • After "=" pressed                   → "\(prev) \(op) \(secondOperand) ="
    //
    // Line 2 (primary / large):
    //   • Always shows currentInput (the live number being typed / the result)
    //
    // We do NOT show a third "= result" row; the result IS line 2 after "=".

    private var topDisplayLine: String {
        guard !previousInput.isEmpty, let op = pendingOp else { return "" }
        let opSym = symbol(for: op)
        if justCalculated {
            // Show full expression  e.g.  "12 + 8 ="
            return "\(fmt(previousInput)) \(opSym) \(fmt(currentInput)) ="
        } else {
            // Show partial expression  e.g.  "12 +"
            return "\(fmt(previousInput)) \(opSym)"
        }
    }

    // Whether AC should read "C"
    private var clearLabel: String {
        currentInput != "0" || justCalculated ? "C" : "AC"
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.background
                .edgesIgnoringSafeArea(.all)
                .animation(.easeInOut(duration: 0.35), value: themeIndex)

            VStack(spacing: 0) {
                topBar
                displayArea
                buttonGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
            }

            // Dim overlay for sheets
            if showSettings || showHistory {
                Color.black.opacity(0.55)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showSettings = false
                            showHistory  = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }

            if showSettings {
                settingsSheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            if showHistory {
                historySheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showSettings)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showHistory)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // History button
            Button {
                hapticLight.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showHistory = true
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(theme.displaySecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(theme.numberDefault))
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(history.isEmpty ? 0.35 : 1.0)
            .disabled(history.isEmpty)

            Spacer()

            // Settings button (3 dots)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showSettings = true
                }
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(theme.functionDefault).frame(width: 8, height: 8)
                    Circle().fill(theme.operationDefault).frame(width: 8, height: 8)
                    Circle().fill(theme.displaySecondary.opacity(0.45)).frame(width: 8, height: 8)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(theme.numberDefault))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 4)
    }

    // MARK: - Display Area

    private var displayArea: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Spacer()

            // Top line: expression / operator context
            Text(topDisplayLine)
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(theme.displaySecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 22)
                .animation(.easeInOut(duration: 0.15), value: topDisplayLine)

            // Main input / result
            Text(displayNumber(currentInput))
                .font(.system(size: 68, weight: .light))
                .foregroundColor(theme.foreground)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.25)
                .padding(.horizontal, 22)
                .animation(.easeInOut(duration: 0.1), value: currentInput)

            Spacer()
        }
        .frame(height: 200)
    }

    // MARK: - Button Grid
    //
    // Layout:
    //   Row 0: AC/C   ±    %    ÷
    //   Row 1: 7      8    9    ×
    //   Row 2: 4      5    6    −
    //   Row 3: 1      2    3    +
    //   Row 4: 0(wide)  ⌫   .   =
    //
    // The backspace (⌫) replaces the old "." position; "." moves between ⌫ and "=".

    private var buttonGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                btn(clearLabel, .function)  { clearOrAllClear() }
                btn("±",        .function)  { toggleSign() }
                btn("%",        .function)  { percentage() }
                btn("÷",        .operation) { setOperation(.divide) }
            }
            HStack(spacing: 12) {
                btn("7", .number)    { appendNumber("7") }
                btn("8", .number)    { appendNumber("8") }
                btn("9", .number)    { appendNumber("9") }
                btn("×", .operation) { setOperation(.multiply) }
            }
            HStack(spacing: 12) {
                btn("4", .number)    { appendNumber("4") }
                btn("5", .number)    { appendNumber("5") }
                btn("6", .number)    { appendNumber("6") }
                btn("−", .operation) { setOperation(.subtract) }
            }
            HStack(spacing: 12) {
                btn("1", .number)    { appendNumber("1") }
                btn("2", .number)    { appendNumber("2") }
                btn("3", .number)    { appendNumber("3") }
                btn("+", .operation) { setOperation(.add) }
            }
            HStack(spacing: 12) {
                btn("0",  .number, wide: true) { appendNumber("0") }
                btn("⌫",  .function)           { backspace() }
                btn(".",  .number)             { appendDecimal() }
                btn("=",  .operation)          { calculate() }
            }
        }
    }

    @ViewBuilder
    private func btn(
        _ title: String,
        _ type: CalcButton.BtnType,
        wide: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        CalcButton(title: title, type: type, isWide: wide, shape: buttonShape, theme: theme, action: action)
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetHandle

            sectionHeader("THEME")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(CalculatorTheme.all) { t in
                        ThemeCard(theme: t, isSelected: t.id == themeIndex) {
                            withAnimation(.easeInOut(duration: 0.35)) { themeIndex = t.id }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
            }
            .padding(.bottom, 26)

            sectionHeader("BUTTON SHAPE")

            HStack(spacing: 12) {
                shapeOption(.circle,  label: "Circle",
                    icon: AnyView(Circle()
                        .fill(theme.operationDefault).frame(width: 22, height: 22)))
                shapeOption(.rounded, label: "Rounded",
                    icon: AnyView(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.operationDefault).frame(width: 22, height: 22)))
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(
            theme.numberDefault
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .edgesIgnoringSafeArea(.bottom)
        )
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - History Sheet

    private var historySheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetHandle

            HStack {
                sectionHeader("HISTORY")
                Spacer()
                if !history.isEmpty {
                    Button {
                        withAnimation { history.removeAll() }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.operationDefault)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 22)
                    .padding(.bottom, 14)
                }
            }

            if history.isEmpty {
                Text("No history yet.")
                    .font(.system(size: 15))
                    .foregroundColor(theme.displaySecondary.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(history.reversed()) { entry in
                            Button {
                                // Tap to restore result
                                currentInput = entry.result
                                previousInput = ""
                                pendingOp = nil
                                shouldClearInput = false
                                justCalculated = false
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    showHistory = false
                                }
                            } label: {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(entry.expression)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(theme.displaySecondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text(entry.result)
                                        .font(.system(size: 24, weight: .light))
                                        .foregroundColor(theme.foreground)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(theme.background.opacity(0.5))
                                        .padding(.horizontal, 14)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 320)
            }

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
        .background(
            theme.numberDefault
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .edgesIgnoringSafeArea(.bottom)
        )
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - Sheet helpers

    private var sheetHandle: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(theme.displaySecondary.opacity(0.3))
                .frame(width: 40, height: 4)
            Spacer()
        }
        .padding(.top, 14)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.4)
            .foregroundColor(theme.displaySecondary.opacity(0.65))
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
    }

    @ViewBuilder
    private func shapeOption(_ shape: ButtonShape, label: String, icon: AnyView) -> some View {
        let sel = buttonShape == shape
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { buttonShape = shape }
        } label: {
            HStack(spacing: 10) {
                icon
                Text(label)
                    .font(.system(size: 15, weight: sel ? .semibold : .regular))
                    .foregroundColor(sel ? theme.foreground : theme.displaySecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(sel ? theme.functionDefault : theme.background.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(sel ? theme.operationDefault : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Formatting helpers

    private func symbol(for op: CalcOperation) -> String {
        switch op {
        case .add:      return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide:   return "÷"
        }
    }

    /// Format a raw number string (no thousands sep while typing, add after result)
    private func displayNumber(_ raw: String) -> String {
        // Keep raw while typing so "1234" doesn't jump around mid-entry.
        // Only format after justCalculated or if string doesn't end with digit (e.g. "1234.")
        if raw == "Error" { return "Error" }
        if justCalculated, let d = Double(raw) { return fmtDouble(d) }
        return raw
    }

    private func fmt(_ raw: String) -> String {
        if let d = Double(raw) { return fmtDouble(d) }
        return raw
    }

    private func fmtDouble(_ n: Double) -> String {
        if n.truncatingRemainder(dividingBy: 1) == 0 && abs(n) < 1e12 {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = ","
            f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: n)) ?? String(format: "%.0f", n)
        }
        // Decimal result — up to 8 sig figs, strip trailing zeros
        var s = String(format: "%.8g", n)
        return s
    }

    // MARK: - Calculator Logic

    private func appendNumber(_ n: String) {
        hapticLight.impactOccurred()
        if justCalculated {
            // Start fresh after a result
            currentInput = n
            previousInput = ""
            pendingOp = nil
            shouldClearInput = false
            justCalculated = false
            return
        }
        if shouldClearInput {
            currentInput = n
            shouldClearInput = false
            return
        }
        if currentInput == "0" && n != "0" { currentInput = n }
        else if currentInput == "0" && n == "0" { return }
        else if currentInput.count < 12 { currentInput += n }
    }

    private func appendDecimal() {
        hapticLight.impactOccurred()
        if justCalculated {
            currentInput = "0."
            previousInput = ""; pendingOp = nil
            shouldClearInput = false; justCalculated = false
            return
        }
        if shouldClearInput {
            currentInput = "0."
            shouldClearInput = false
            return
        }
        if !currentInput.contains(".") { currentInput += "." }
    }

    private func backspace() {
        hapticLight.impactOccurred()
        if justCalculated {
            clearAll(); return
        }
        if currentInput == "Error" { currentInput = "0"; return }
        if shouldClearInput { return }
        if currentInput.count <= 1 || (currentInput.hasPrefix("-") && currentInput.count == 2) {
            currentInput = "0"
        } else {
            currentInput.removeLast()
        }
    }

    private func setOperation(_ op: CalcOperation) {
        hapticMedium.impactOccurred()
        // If there's a pending op and user just typed a number, chain calculate
        if !previousInput.isEmpty && !shouldClearInput && !justCalculated {
            calculateSilently()
        }
        previousInput = currentInput
        pendingOp = op
        shouldClearInput = true
        justCalculated = false
    }

    private func calculate() {
        hapticMedium.impactOccurred()
        guard let prev = Double(previousInput),
              let curr = Double(currentInput),
              let op   = pendingOp else { return }

        let result = applyOp(op, prev, curr)
        guard let result = result else {
            hapticError.notificationOccurred(.error)
            currentInput = "Error"
            previousInput = ""; pendingOp = nil
            shouldClearInput = true; justCalculated = true
            return
        }

        // Save to history
        let expr = "\(fmt(previousInput)) \(symbol(for: op)) \(fmt(currentInput))"
        let rs = resultString(result)
        history.append(HistoryEntry(expression: expr, result: rs))

        currentInput = rs
        shouldClearInput = true
        justCalculated = true
        // keep previousInput and pendingOp so topDisplayLine shows full expression
    }

    /// Silent calculate for chaining (no haptic, no history entry)
    private func calculateSilently() {
        guard let prev = Double(previousInput),
              let curr = Double(currentInput),
              let op   = pendingOp else { return }
        guard let result = applyOp(op, prev, curr) else { return }
        currentInput = resultString(result)
    }

    private func applyOp(_ op: CalcOperation, _ a: Double, _ b: Double) -> Double? {
        switch op {
        case .add:      return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        case .divide:
            guard b != 0 else { return nil }
            return a / b
        }
    }

    private func resultString(_ n: Double) -> String {
        if n.truncatingRemainder(dividingBy: 1) == 0 && abs(n) < 1e12 {
            return String(format: "%.0f", n)
        }
        var s = String(format: "%.8g", n)
        return s
    }

    private func clearOrAllClear() {
        hapticMedium.impactOccurred()
        if clearLabel == "C" {
            // Just clear current input
            currentInput = "0"
            justCalculated = false
            shouldClearInput = false
        } else {
            clearAll()
        }
    }

    private func clearAll() {
        hapticMedium.impactOccurred()
        currentInput = "0"
        previousInput = ""
        pendingOp = nil
        shouldClearInput = false
        justCalculated = false
    }

    private func toggleSign() {
        hapticLight.impactOccurred()
        guard currentInput != "0", currentInput != "Error" else { return }
        if justCalculated { justCalculated = false }
        currentInput = currentInput.hasPrefix("-")
            ? String(currentInput.dropFirst())
            : "-" + currentInput
    }

    private func percentage() {
        hapticLight.impactOccurred()
        guard let v = Double(currentInput) else { return }
        let r = v / 100
        currentInput = resultString(r)
        if justCalculated { justCalculated = false }
    }
}

// MARK: - CalcButton

struct CalcButton: View {
    let title: String
    let type: BtnType
    let isWide: Bool
    let shape: ButtonShape
    let theme: CalculatorTheme
    let action: () -> Void

    @State private var isPressed = false

    enum BtnType { case number, function, operation }

    private var bgColor: Color {
        switch type {
        case .number:    return isPressed ? theme.numberPressed    : theme.numberDefault
        case .function:  return isPressed ? theme.functionPressed  : theme.functionDefault
        case .operation: return isPressed ? theme.operationPressed : theme.operationDefault
        }
    }

    // Use SF Symbol for backspace for clarity
    private var isBackspace: Bool { title == "⌫" }

    var body: some View {
        Button(action: action) {
            ZStack {
                bgColor
                    .modifier(ButtonShapeClip(shape: shape, isWide: isWide))

                if isBackspace {
                    Image(systemName: "delete.left")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundColor(theme.foreground)
                } else {
                    Text(title)
                        .font(.system(size: 30, weight: .regular))
                        .foregroundColor(theme.foreground)
                }
            }
            .frame(width: isWide ? 164 : 76, height: 76)
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shape)
        }
        .buttonStyle(PlainButtonStyle())
        .background(ButtonPressDetector(isPressed: $isPressed))
    }
}

// MARK: - Shape Clip Modifier

struct ButtonShapeClip: ViewModifier {
    let shape: ButtonShape
    let isWide: Bool
    func body(content: Content) -> some View {
        switch shape {
        case .circle:
            content.clipShape(isWide ? AnyShape(Capsule()) : AnyShape(Circle()))
        case .rounded:
            content.clipShape(AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
        }
    }
}

// MARK: - AnyShape

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ s: S) { _path = s.path(in:) }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: CalculatorTheme
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.background)
                        .frame(width: 64, height: 72)
                    VStack(spacing: 5) {
                        HStack {
                            Spacer()
                            Text("9")
                                .font(.system(size: 14, weight: .thin))
                                .foregroundColor(theme.foreground)
                                .padding(.trailing, 7).padding(.top, 5)
                        }
                        VStack(spacing: 3) {
                            miniRow([theme.functionDefault, theme.functionDefault,
                                     theme.functionDefault, theme.operationDefault])
                            miniRow([theme.numberDefault,   theme.numberDefault,
                                     theme.numberDefault,   theme.operationDefault])
                        }
                        .padding(.horizontal, 5).padding(.bottom, 5)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isSelected ? theme.operationDefault : Color.white.opacity(0.07),
                            lineWidth: isSelected ? 2.5 : 0.5
                        )
                )
                .scaleEffect(isSelected ? 1.06 : (pressed ? 0.93 : 1.0))
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

                Text(theme.emoji).font(.system(size: 14))
                Text(theme.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.operationDefault : theme.displaySecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        ._onButtonGesture(pressing: { p in pressed = p }, perform: {})
    }

    @ViewBuilder
    private func miniRow(_ colors: [Color]) -> some View {
        HStack(spacing: 2) {
            ForEach(colors.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3).fill(colors[i]).frame(width: 11, height: 8)
            }
        }
    }
}

// MARK: - Button Press Detector

struct ButtonPressDetector: UIViewRepresentable {
    @Binding var isPressed: Bool
    func makeUIView(context: Context) -> UIButton {
        let b = UIButton(); b.backgroundColor = .clear
        b.addAction(UIAction { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true  } }, for: .touchDown)
        b.addAction(UIAction { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return b
    }
    func updateUIView(_ uiView: UIButton, context: Context) {}
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDevice("iPhone 14 Pro")
    }
}
