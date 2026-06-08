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
        id: 0, name: "Obsidian", emoji: "🌑",
        background:       Color(red: 0.06, green: 0.06, blue: 0.08),
        displaySecondary: Color(red: 0.55, green: 0.53, blue: 0.58),
        numberDefault:    Color(red: 0.14, green: 0.14, blue: 0.16),
        numberPressed:    Color(red: 0.22, green: 0.22, blue: 0.25),
        functionDefault:  Color(red: 0.24, green: 0.23, blue: 0.27),
        functionPressed:  Color(red: 0.34, green: 0.33, blue: 0.38),
        operationDefault: Color(red: 1.00, green: 0.62, blue: 0.04),
        operationPressed: Color(red: 1.00, green: 0.76, blue: 0.30),
        foreground: .white
    )
    static let light = CalculatorTheme(
        id: 1, name: "Pearl", emoji: "✨",
        background:       Color(red: 0.96, green: 0.95, blue: 0.93),
        displaySecondary: Color(red: 0.42, green: 0.40, blue: 0.44),
        numberDefault:    Color(red: 1.00, green: 1.00, blue: 1.00),
        numberPressed:    Color(red: 0.90, green: 0.89, blue: 0.87),
        functionDefault:  Color(red: 0.85, green: 0.84, blue: 0.82),
        functionPressed:  Color(red: 0.75, green: 0.74, blue: 0.72),
        operationDefault: Color(red: 0.18, green: 0.18, blue: 0.22),
        operationPressed: Color(red: 0.32, green: 0.32, blue: 0.38),
        foreground: Color(red: 0.10, green: 0.10, blue: 0.12)
    )
    static let ocean = CalculatorTheme(
        id: 2, name: "Ocean", emoji: "🌊",
        background:       Color(red: 0.03, green: 0.07, blue: 0.16),
        displaySecondary: Color(red: 0.40, green: 0.62, blue: 0.88),
        numberDefault:    Color(red: 0.07, green: 0.13, blue: 0.25),
        numberPressed:    Color(red: 0.10, green: 0.20, blue: 0.36),
        functionDefault:  Color(red: 0.09, green: 0.20, blue: 0.38),
        functionPressed:  Color(red: 0.13, green: 0.28, blue: 0.48),
        operationDefault: Color(red: 0.20, green: 0.56, blue: 1.00),
        operationPressed: Color(red: 0.40, green: 0.70, blue: 1.00),
        foreground: .white
    )
    static let rose = CalculatorTheme(
        id: 3, name: "Rosé", emoji: "🌸",
        background:       Color(red: 0.08, green: 0.04, blue: 0.07),
        displaySecondary: Color(red: 0.78, green: 0.50, blue: 0.65),
        numberDefault:    Color(red: 0.16, green: 0.08, blue: 0.13),
        numberPressed:    Color(red: 0.26, green: 0.14, blue: 0.20),
        functionDefault:  Color(red: 0.28, green: 0.12, blue: 0.20),
        functionPressed:  Color(red: 0.40, green: 0.18, blue: 0.28),
        operationDefault: Color(red: 1.00, green: 0.36, blue: 0.56),
        operationPressed: Color(red: 1.00, green: 0.55, blue: 0.70),
        foreground: .white
    )
    static let mint = CalculatorTheme(
        id: 4, name: "Jade", emoji: "🌿",
        background:       Color(red: 0.03, green: 0.08, blue: 0.07),
        displaySecondary: Color(red: 0.38, green: 0.75, blue: 0.62),
        numberDefault:    Color(red: 0.06, green: 0.16, blue: 0.14),
        numberPressed:    Color(red: 0.10, green: 0.26, blue: 0.22),
        functionDefault:  Color(red: 0.08, green: 0.24, blue: 0.20),
        functionPressed:  Color(red: 0.14, green: 0.36, blue: 0.30),
        operationDefault: Color(red: 0.16, green: 0.84, blue: 0.60),
        operationPressed: Color(red: 0.30, green: 0.94, blue: 0.72),
        foreground: .white
    )
}

// MARK: - Button Shape

enum ButtonShape: CaseIterable { case circle, rounded }

// MARK: - History Entry

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let expression: String  // e.g. "12 + 8"
    let result: String      // e.g. "20"
    let timestamp: Date

    init(expression: String, result: String) {
        self.id = UUID()
        self.expression = expression
        self.result = result
        self.timestamp = Date()
    }

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }

    var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: timestamp)
    }
}

// MARK: - Content View

struct ContentView: View {

    // Calculator state
    @State private var currentInput: String = "0"
    @State private var previousInput: String = ""
    @State private var secondOperand: String = ""     // saved before overwrite by result
    @State private var pendingOp: CalcOperation? = nil
    @State private var shouldClearInput: Bool = false
    @State private var justCalculated: Bool = false   // true right after "=" pressed

    // History
    @State private var history: [HistoryEntry] = []
    @State private var showHistory: Bool = false

    // UI – persisted
    @AppStorage("themeIndex") private var themeIndex: Int = 0
    @AppStorage("buttonShapeRaw") private var buttonShapeRaw: String = "circle"
    private var buttonShape: ButtonShape {
        get { buttonShapeRaw == "rounded" ? .rounded : .circle }
    }
    @State private var showSettings: Bool = false
    @State private var activeOp: CalcOperation? = nil  // currently highlighted operator

    // Toast
    @State private var showCopiedToast: Bool = false

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
            return "\(fmt(previousInput)) \(opSym) \(fmt(secondOperand)) ="
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

    private let gridSpacing: CGFloat = 12
    private let btnHeight: CGFloat = 76

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [theme.background, theme.background, theme.numberDefault.opacity(0.3)],
                startPoint: .top, endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            .animation(.easeInOut(duration: 0.45), value: themeIndex)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 4)
                displayArea
                Spacer(minLength: 12)
                buttonGrid
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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

            // Copied toast
            if showCopiedToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Copied")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(theme.foreground)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(theme.operationDefault)
                            .shadow(color: theme.operationDefault.opacity(0.4), radius: 12, y: 4)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.8)))
                    .padding(.bottom, 100)
                }
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showSettings)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showHistory)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showCopiedToast)
        .onAppear { loadHistory() }
        .onChange(of: history.count) { _ in saveHistory() }
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.displaySecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(theme.numberDefault.opacity(0.8))
                            .overlay(Circle().strokeBorder(theme.displaySecondary.opacity(0.1), lineWidth: 0.5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(history.isEmpty ? 0.3 : 1.0)
            .disabled(history.isEmpty)

            Spacer()

            // App branding
            Text("Calc")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(theme.displaySecondary.opacity(0.4))
                .tracking(2)

            Spacer()

            // Settings button
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showSettings = true
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.displaySecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(theme.numberDefault.opacity(0.8))
                            .overlay(Circle().strokeBorder(theme.displaySecondary.opacity(0.1), lineWidth: 0.5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Display Area

    private var displayArea: some View {
        VStack(alignment: .trailing, spacing: 6) {
            // Top line: expression / operator context
            Text(topDisplayLine)
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(theme.displaySecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.15), value: topDisplayLine)

            // Main input / result
            Text(displayNumber(currentInput))
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .foregroundColor(theme.foreground)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .padding(.horizontal, 28)
                .shadow(color: theme.operationDefault.opacity(justCalculated ? 0.35 : 0), radius: 24, y: 4)
                .shadow(color: theme.operationDefault.opacity(justCalculated ? 0.15 : 0), radius: 48, y: 8)
                .animation(.easeInOut(duration: 0.2), value: currentInput)
                .animation(.easeInOut(duration: 0.5), value: justCalculated)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.numberDefault.opacity(0.25))
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [theme.displaySecondary.opacity(0.12), theme.displaySecondary.opacity(0.02)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .padding(.horizontal, 14)
        )
        .onLongPressGesture(minimumDuration: 0.4) {
            copyResult()
        }
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
        VStack(spacing: gridSpacing) {
            gridRow {
                btn(clearLabel, .function)  { clearOrAllClear() }
                btn("±",        .function)  { toggleSign() }
                btn("%",        .function)  { percentage() }
                btn("÷",        .operation, active: activeOp == .divide) { setOperation(.divide) }
            }
            gridRow {
                btn("7", .number) { appendNumber("7") }
                btn("8", .number) { appendNumber("8") }
                btn("9", .number) { appendNumber("9") }
                btn("×", .operation, active: activeOp == .multiply) { setOperation(.multiply) }
            }
            gridRow {
                btn("4", .number) { appendNumber("4") }
                btn("5", .number) { appendNumber("5") }
                btn("6", .number) { appendNumber("6") }
                btn("−", .operation, active: activeOp == .subtract) { setOperation(.subtract) }
            }
            gridRow {
                btn("1", .number) { appendNumber("1") }
                btn("2", .number) { appendNumber("2") }
                btn("3", .number) { appendNumber("3") }
                btn("+", .operation, active: activeOp == .add) { setOperation(.add) }
            }
            // Bottom row: 0 is double-wide
            HStack(spacing: gridSpacing) {
                btn("0", .number, wide: true) { appendNumber("0") }
                btn("⌫", .function) { backspace() }
                btn(".", .number) { appendDecimal() }
                btn("=", .operation) { calculate() }
            }
            .frame(height: btnHeight)
        }
    }

    @ViewBuilder
    private func gridRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: gridSpacing) {
            content()
        }
        .frame(height: btnHeight)
    }

    @ViewBuilder
    private func btn(
        _ title: String,
        _ type: CalcButton.BtnType,
        wide: Bool = false,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        CalcButton(title: title, type: type, isWide: wide, shape: buttonShape, theme: theme, isActive: active, action: action)
    }

    // MARK: - Settings Sheet

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetHandle

            Text("Settings")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(theme.foreground)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            sectionHeader("THEME")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(CalculatorTheme.all) { t in
                        ThemeCard(theme: t, isSelected: t.id == themeIndex) {
                            hapticLight.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.35)) { themeIndex = t.id }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)
            }
            .padding(.bottom, 28)

            sectionHeader("BUTTON SHAPE")

            HStack(spacing: 12) {
                shapeOption(.circle,  label: "Circle",
                    icon: AnyView(Circle()
                        .fill(theme.operationDefault).frame(width: 20, height: 20)))
                shapeOption(.rounded, label: "Rounded",
                    icon: AnyView(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.operationDefault).frame(width: 20, height: 20)))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(theme.numberDefault.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(theme.displaySecondary.opacity(0.08), lineWidth: 0.5)
                )
                .edgesIgnoringSafeArea(.bottom)
        )
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - History Sheet

    private var historySheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            sheetHandle

            HStack(alignment: .center) {
                Text("History")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.foreground)
                Spacer()
                if !history.isEmpty {
                    Button {
                        withAnimation { history.removeAll() }
                    } label: {
                        Text("Clear All")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.operationDefault)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(theme.operationDefault.opacity(0.12))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(theme.displaySecondary.opacity(0.35))
                    Text("No calculations yet")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(theme.displaySecondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 36)
            } else {
                List {
                    ForEach(Array(history.reversed().enumerated()), id: \.element.id) { idx, entry in
                        Button {
                            currentInput = entry.result
                            previousInput = ""
                            pendingOp = nil
                            shouldClearInput = false
                            justCalculated = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showHistory = false
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                // Timestamp
                                VStack(spacing: 2) {
                                    Text(entry.timeString)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                    Text(entry.dateString)
                                        .font(.system(size: 9, weight: .regular, design: .rounded))
                                }
                                .foregroundColor(theme.displaySecondary.opacity(0.4))
                                .frame(width: 44)

                                // Divider
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(theme.displaySecondary.opacity(0.1))
                                    .frame(width: 1, height: 32)

                                // Expression & result
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(entry.expression)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(theme.displaySecondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text(entry.result)
                                        .font(.system(size: 22, weight: .light, design: .rounded))
                                        .foregroundColor(theme.foreground)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.background.opacity(0.5))
                                .padding(.vertical, 3)
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteHistoryEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxHeight: 320)
            }

            Spacer().frame(height: 44)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(theme.numberDefault.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(theme.displaySecondary.opacity(0.08), lineWidth: 0.5)
                )
                .edgesIgnoringSafeArea(.bottom)
        )
        .edgesIgnoringSafeArea(.bottom)
    }

    // MARK: - Sheet helpers

    private var sheetHandle: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(theme.displaySecondary.opacity(0.25))
                .frame(width: 36, height: 4)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.6)
            .foregroundColor(theme.displaySecondary.opacity(0.5))
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
    }

    @ViewBuilder
    private func shapeOption(_ shape: ButtonShape, label: String, icon: AnyView) -> some View {
        let sel = buttonShape == shape
        Button {
            hapticLight.impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                buttonShapeRaw = shape == .rounded ? "rounded" : "circle"
            }
        } label: {
            HStack(spacing: 10) {
                icon
                Text(label)
                    .font(.system(size: 14, weight: sel ? .semibold : .regular, design: .rounded))
                    .foregroundColor(sel ? theme.foreground : theme.displaySecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(sel ? theme.functionDefault : theme.background.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(sel ? theme.operationDefault.opacity(0.6) : theme.displaySecondary.opacity(0.08), lineWidth: sel ? 1.5 : 0.5)
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
        return String(format: "%.8g", n)
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
            activeOp = nil
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
        activeOp = op
        shouldClearInput = true
        justCalculated = false
    }

    private func calculate() {
        hapticMedium.impactOccurred()
        guard let prev = Double(previousInput),
              let curr = Double(currentInput),
              let op   = pendingOp else { return }

        // Save second operand BEFORE overwriting currentInput
        secondOperand = currentInput

        let result = applyOp(op, prev, curr)
        guard let result = result else {
            hapticError.notificationOccurred(.error)
            currentInput = "Error"
            previousInput = ""; pendingOp = nil
            shouldClearInput = true; justCalculated = true
            return
        }

        // Save to history
        let expr = "\(fmt(previousInput)) \(symbol(for: op)) \(fmt(secondOperand))"
        let rs = resultString(result)
        history.append(HistoryEntry(expression: expr, result: rs))

        currentInput = rs
        shouldClearInput = true
        justCalculated = true
        activeOp = nil
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
        return String(format: "%.8g", n)
    }

    private func clearOrAllClear() {
        hapticMedium.impactOccurred()
        if clearLabel == "C" {
            // Just clear current input
            currentInput = "0"
            justCalculated = false
            shouldClearInput = false
            secondOperand = ""
        } else {
            clearAll()
        }
    }

    private func clearAll() {
        hapticMedium.impactOccurred()
        currentInput = "0"
        previousInput = ""
        secondOperand = ""
        pendingOp = nil
        activeOp = nil
        shouldClearInput = false
        justCalculated = false
    }

    private func toggleSign() {
        hapticLight.impactOccurred()
        guard currentInput != "0", currentInput != "Error" else { return }
        if justCalculated { justCalculated = false; previousInput = ""; pendingOp = nil }
        if shouldClearInput { currentInput = "0"; shouldClearInput = false; return }
        currentInput = currentInput.hasPrefix("-")
            ? String(currentInput.dropFirst())
            : "-" + currentInput
    }

    private func percentage() {
        hapticLight.impactOccurred()
        if justCalculated { justCalculated = false; previousInput = ""; pendingOp = nil }
        if shouldClearInput { currentInput = "0"; shouldClearInput = false }
        guard let v = Double(currentInput) else { return }
        let r = v / 100
        currentInput = resultString(r)
    }

    // MARK: - Copy to Clipboard

    private func copyResult() {
        guard currentInput != "0" && currentInput != "Error" else { return }
        UIPasteboard.general.string = currentInput
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopiedToast = false }
        }
    }

    // MARK: - History Persistence

    private func deleteHistoryEntry(_ entry: HistoryEntry) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            history.removeAll { $0.id == entry.id }
        }
    }

    private func saveHistory() {
        // Keep only last 50 entries
        let trimmed = Array(history.suffix(50))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: "calcHistory")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "calcHistory"),
              let saved = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        history = saved
    }
}

// MARK: - CalcButton

struct CalcButton: View {
    let title: String
    let type: BtnType
    var isWide: Bool = false
    let shape: ButtonShape
    let theme: CalculatorTheme
    var isActive: Bool = false
    let action: () -> Void

    @State private var isPressed = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0

    enum BtnType { case number, function, operation }

    private var bgColor: Color {
        if isActive && type == .operation {
            return theme.foreground
        }
        switch type {
        case .number:    return isPressed ? theme.numberPressed    : theme.numberDefault
        case .function:  return isPressed ? theme.functionPressed  : theme.functionDefault
        case .operation: return isPressed ? theme.operationPressed : theme.operationDefault
        }
    }

    private var fgColor: Color {
        if isActive && type == .operation {
            return theme.operationDefault
        }
        return theme.foreground
    }

    private var isBackspace: Bool { title == "⌫" }
    private var isEquals: Bool { title == "=" }

    var body: some View {
        Button(action: {
            triggerRipple()
            action()
        }) {
            ZStack {
                // Base color
                bgColor
                    .modifier(ButtonShapeClip(shape: shape, isWide: isWide))

                // Gradient overlay for = button
                if isEquals && type == .operation && !isActive {
                    LinearGradient(
                        colors: [
                            theme.operationDefault.opacity(0.0),
                            theme.operationDefault.opacity(0.15),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                    .modifier(ButtonShapeClip(shape: shape, isWide: isWide))
                }

                // Subtle top highlight for 3D depth on operation buttons
                if type == .operation && !isActive {
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                    .modifier(ButtonShapeClip(shape: shape, isWide: isWide))
                    .allowsHitTesting(false)
                }

                // Ripple ring
                Circle()
                    .strokeBorder(theme.foreground.opacity(rippleOpacity), lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .allowsHitTesting(false)

                // Button content
                if isBackspace {
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(fgColor)
                } else {
                    Text(title)
                        .font(.system(size: isEquals ? 32 : 28, weight: type == .operation ? .medium : .regular, design: .rounded))
                        .foregroundColor(fgColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(
                color: type == .operation && !isActive
                    ? theme.operationDefault.opacity(isPressed ? 0.1 : 0.3)
                    : Color.clear,
                radius: isPressed ? 4 : 10, y: isPressed ? 1 : 4
            )
            .scaleEffect(isPressed ? 0.91 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: isPressed)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shape)
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.65)) { isPressed = false }
                }
        )
    }

    private func triggerRipple() {
        rippleScale = 0.3
        rippleOpacity = 0.5
        withAnimation(.easeOut(duration: 0.5)) {
            rippleScale = 1.2
            rippleOpacity = 0
        }
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

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().previewDevice("iPhone 14 Pro")
    }
}
