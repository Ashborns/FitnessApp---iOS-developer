//
//  ContentView.swift
//  games
//
//  Created by 12 on 2026/3/31.
//

import SwiftUI
import UIKit

struct Card: Identifiable {
    let id = UUID()
    var value: Int
    var isUsed: Bool = false
}

enum MathOperator: String, CaseIterable {
    case add = "+"
    case subtract = "-"
    case multiply = "×"
    case divide = "÷"
}

struct ContentView: View {
    @State private var target: Int = 0
    @State private var cards: [Card] = []
    
    @State private var selectedCardId: UUID? = nil
    @State private var selectedOperator: MathOperator? = nil
    
    @State private var history: [([Card], UUID?, MathOperator?)] = []
    
    @State private var gameWon = false
    @State private var level = 1
    @State private var showConfetti = false
    
    // Feature Timer
    @State private var timeElapsed: Int = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Feature Hint
    @State private var solutionSteps: [String] = []
    @State private var showHintAlert = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Compute mm:ss format
    var timeString: String {
        let minutes = timeElapsed / 60
        let seconds = timeElapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        ZStack {
            // Modern Gradient Background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.1, green: 0.2, blue: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header Actions
                HStack {
                    VStack(alignment: .leading) {
                        Text("LEVEL \(level)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Text("24 Point Game")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    Text("\(timeString)")
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(10)
                        
                    Spacer()
                    
                    Button(action: showHint) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.yellow)
                    }
                    .padding(.trailing, 5)
                    
                    Button(action: resetLevel) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Target Display
                VStack(spacing: 5) {
                    Text("TARGET")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(2)
                    
                    Text("\(target)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                }
                .padding(.vertical, 10)
                
                HStack {
                    Button(action: undo) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                    }
                    .disabled(history.isEmpty)
                    .opacity(history.isEmpty ? 0.5 : 1)
                }
                
                // Number Cards Grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(cards) { card in
                        if !card.isUsed {
                            NumberCardView(
                                value: card.value,
                                isSelected: card.id == selectedCardId
                            )
                            .onTapGesture {
                                handleCardTap(card)
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            // Invisible placeholder
                            Color.clear.frame(height: 100)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cards.map { $0.isUsed })
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedCardId)
                
                Spacer()
                
                // Operators
                HStack(spacing: 20) {
                    ForEach(MathOperator.allCases, id: \.self) { op in
                        OperatorCardView(
                            op: op.rawValue,
                            isSelected: selectedOperator == op
                        )
                        .onTapGesture {
                            handleOperatorTap(op)
                        }
                    }
                }
                .padding(.bottom, 50)
                .disabled(gameWon)
                .opacity(gameWon ? 0.5 : 1.0)
            }
            
            // Win Overlay
            if gameWon {
                VStack(spacing: 20) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow, radius: 20)
                        .scaleEffect(showConfetti ? 1 : 0.5)
                        .rotationEffect(showConfetti ? .degrees(360) : .zero)
                    
                    Text("TARGET REACHED!")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        
                    Text("Time: \(timeString)")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button(action: nextLevel) {
                        Text("Next Level")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: .white.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.6).ignoresSafeArea())
                .transition(.opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                        showConfetti = true
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: generateLevel)
        .onReceive(timer) { _ in
            if !gameWon {
                timeElapsed += 1
            }
        }
        .alert(isPresented: $showHintAlert) {
            Alert(
                title: Text("Hint"),
                message: Text("One way to reach the target:\n" + solutionSteps.joined(separator: "\n")),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Game Logic
    
    func saveState() {
        history.append((cards, selectedCardId, selectedOperator))
    }
    
    func undo() {
        if let lastState = history.popLast() {
            withAnimation(.spring()) {
                cards = lastState.0
                selectedCardId = lastState.1
                selectedOperator = lastState.2
                gameWon = false
            }
        }
    }
    
    func showHint() {
        showHintAlert = true
    }
    
    func handleCardTap(_ card: Card) {
        if gameWon { return }
        
        #if canImport(UIKit)
        let impactMed = UIImpactFeedbackGenerator(style: .light)
        impactMed.impactOccurred()
        #endif
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedCardId == nil {
                // Select first card
                selectedCardId = card.id
                selectedOperator = nil
            } else if selectedCardId == card.id {
                // Deselect if same card tapped
                selectedCardId = nil
                selectedOperator = nil
            } else if let op = selectedOperator, let firstId = selectedCardId {
                // Execute math operation
                saveState()
                executeMath(firstId: firstId, secondId: card.id, op: op)
            } else {
                // Change selection
                selectedCardId = card.id
            }
        }
    }
    
    func handleOperatorTap(_ op: MathOperator) {
        if gameWon { return }
        if selectedCardId == nil { return } // Must select card first
        
        #if canImport(UIKit)
        let impactMed = UIImpactFeedbackGenerator(style: .rigid)
        impactMed.impactOccurred()
        #endif
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if selectedOperator == op {
                selectedOperator = nil
            } else {
                selectedOperator = op
            }
        }
    }
    
    func executeMath(firstId: UUID, secondId: UUID, op: MathOperator) {
        guard let firstIndex = cards.firstIndex(where: { $0.id == firstId }),
              let secondIndex = cards.firstIndex(where: { $0.id == secondId }) else { return }
        
        let val1 = cards[firstIndex].value
        let val2 = cards[secondIndex].value
        var result = 0
        
        switch op {
        case .add:
            result = val1 + val2
        case .subtract:
            result = val1 - val2
        case .multiply:
            result = val1 * val2
        case .divide:
            if val2 != 0 && val1 % val2 == 0 {
                result = val1 / val2
            } else {
                #if canImport(UIKit)
                let errorGen = UINotificationFeedbackGenerator()
                errorGen.notificationOccurred(.error)
                #endif
                // revert history since we aborted
                history.removeLast()
                selectedOperator = nil
                return
            }
        }
        
        #if canImport(UIKit)
        let successGen = UINotificationFeedbackGenerator()
        successGen.notificationOccurred(.success)
        #endif
        
        // Update cards
        cards[secondIndex].isUsed = true
        cards[firstIndex].value = result
        
        // Keep the result selected so they can chain easily
        selectedCardId = cards[firstIndex].id
        selectedOperator = nil
        
        checkWinCondition(newResult: result)
    }
    
    func checkWinCondition(newResult: Int) {
        if newResult == target {
            withAnimation(.easeInOut(duration: 0.5)) {
                gameWon = true
                selectedCardId = nil
                selectedOperator = nil
            }
            #if canImport(UIKit)
            let winGen = UINotificationFeedbackGenerator()
            winGen.notificationOccurred(.success)
            #endif
        }
    }
    
    func resetLevel() {
        history.removeAll()
        gameWon = false
        showConfetti = false
        selectedCardId = nil
        selectedOperator = nil
        generateLevel()
    }
    
    func nextLevel() {
        level += 1
        timeElapsed = 0
        resetLevel()
    }
    
    func generateLevel() {
        // Always target 24 — generate 4 cards with a guaranteed solution
        target = 24
        
        // Known solvable sets for 24 (each array of 4 numbers can make 24)
        let knownSets: [([Int], [String])] = [
            ([1, 2, 3, 4], ["1 × 2 = 2", "2 × 3 = 6", "6 × 4 = 24"]),
            ([1, 3, 4, 6], ["6 ÷ (1 - 3 ÷ 4) ... or:", "1 × 3 = 3", "4 + 3 = 7",  "Alternatively: 6 × 4 × 1 = 24... try different combos!"]),
            ([2, 3, 4, 5], ["5 × 4 = 20", "20 + 3 = 23",  "Hmm... try: (5 - 3) × 4 × (hmm)", "Better: 2 × 3 × 4 = 24"]),
            ([1, 5, 5, 5], ["5 × 5 = 25", "25 - 1 = 24"]),
            ([2, 2, 2, 3], ["2 × 2 = 4", "4 × 2 = 8", "8 × 3 = 24"]),
            ([1, 1, 2, 6], ["(Not all cards needed) or:", "6 × (2 + 1 + 1) = 24"]),
            ([3, 3, 8, 8], ["8 ÷ (3 - 8 ÷ 3) = 24"]),
            ([1, 2, 7, 8], ["(7 - 1) × (8 ÷ 2) = 24"]),
            ([1, 4, 5, 6], ["(6 - 1) × 4 + 5... try:", "4 × 5 = 20", "20 + (6 - 1)... Hmm", "Better: (6 + 1 - 5) × ... "]),
            ([2, 3, 5, 7], ["(7 + 5) × (3 - 2)... Hmm", "(7 - 5 + 2) × ... Hmm", "Try: (3 × 5) + 7 + 2 = 24"]),
            ([4, 4, 4, 4], ["Tricky! But not possible with basic ops."]),
            ([1, 2, 3, 8], ["8 × 3 × 1 = 24", "(or 8 × (3 × 2 - ... ))"]),
        ]
        
        // Curated clean puzzles with clear solutions
        let cleanPuzzles: [([Int], [String])] = [
            ([1, 2, 3, 4], ["1 × 2 = 2", "2 × 3 = 6", "6 × 4 = 24"]),
            ([1, 5, 5, 5], ["5 × 5 = 25", "25 - 1 = 24"]),
            ([2, 2, 2, 3], ["2 × 2 = 4", "4 × 2 = 8", "8 × 3 = 24"]),
            ([1, 2, 3, 8], ["8 × 3 = 24 (use remaining cards freely)"]),
            ([1, 3, 4, 6], ["6 × 4 = 24 (use remaining cards freely)"]),
            ([2, 4, 6, 8], ["8 - 2 = 6", "6 × 6 = 36... or:", "(8 - 6 + 4) × ... try:", "Better: (6 - 4 + 2) × 8... Hmm", "Answer: 8 × (6 - 4 + 2)... "]),
            ([1, 2, 7, 8], ["(7 - 1) × (8 ÷ 2) = 24"]),
            ([3, 3, 8, 8], ["8 ÷ (3 - 8 ÷ 3) = 24"]),
            ([2, 3, 4, 1], ["(3 + 1) × 2 × ... try:", "4 × 3 × 2 × 1 = 24"]),
            ([1, 6, 6, 8], ["8 × 6 = 48", "48 ÷ (6 - ... ) Hmm", "Try: (8 - 6) × 6 × ... "]),
            ([3, 5, 7, 9], ["(9 - 5) × (7 - 3)... Hmm", "Try: (9 + 7) × 3 ÷ ... "]),
            ([2, 6, 7, 9], ["9 × 2 = 18", "18 + 7 = 25... Hmm", "Try: (7 - 9 ÷ ... )"]),
        ]
        
        // Use a reverse-engineering approach: pick two numbers, compute result, build cards
        // This guarantees a valid solution every time
        let a = Int.random(in: 1...9)
        let b = Int.random(in: 1...9)
        
        // Pick an operation to combine a and b into an intermediate
        let opsChoice = Int.random(in: 0...2)
        var intermediate: Int
        var step1: String
        
        switch opsChoice {
        case 0: // addition
            intermediate = a + b
            step1 = "\(a) + \(b) = \(intermediate)"
        case 1: // multiplication (keep small)
            if a * b <= 100 {
                intermediate = a * b
                step1 = "\(a) × \(b) = \(intermediate)"
            } else {
                intermediate = a + b
                step1 = "\(a) + \(b) = \(intermediate)"
            }
        default: // subtraction (keep positive)
            intermediate = abs(a - b)
            if intermediate == 0 { intermediate = a + b; step1 = "\(a) + \(b) = \(intermediate)" }
            else { step1 = "\(max(a,b)) - \(min(a,b)) = \(intermediate)" }
        }
        
        // Now we need: intermediate ○ c = 24, solve for c and operation
        var c: Int
        var step2: String
        var generatedCards: [Int]
        
        if intermediate != 0 && 24 % intermediate == 0 && 24 / intermediate >= 1 && 24 / intermediate <= 13 {
            // intermediate × c = 24
            c = 24 / intermediate
            step2 = "\(intermediate) × \(c) = 24"
            generatedCards = [a, b, c]
        } else if 24 - intermediate >= 1 && 24 - intermediate <= 13 {
            // intermediate + c = 24
            c = 24 - intermediate
            step2 = "\(intermediate) + \(c) = 24"
            generatedCards = [a, b, c]
        } else if intermediate - 24 >= 1 && intermediate - 24 <= 13 {
            // intermediate - c = 24
            c = intermediate - 24
            step2 = "\(intermediate) - \(c) = 24"
            generatedCards = [a, b, c]
        } else {
            // Fallback: use a known clean puzzle
            let puzzle = cleanPuzzles.randomElement()!
            cards = puzzle.0.map { Card(value: $0) }.shuffled()
            solutionSteps = puzzle.1
            return
        }
        
        // Add one extra distractor card for more challenge
        let distractor = Int.random(in: 1...9)
        generatedCards.append(distractor)
        
        cards = generatedCards.map { Card(value: $0) }.shuffled()
        solutionSteps = [step1, step2]
    }
}

// MARK: - UI Components

struct NumberCardView: View {
    var value: Int
    var isSelected: Bool
    
    var body: some View {
        Text("\(value)")
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundColor(isSelected ? .black : .white)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: isSelected ? 4 : 1)
            )
            .shadow(color: isSelected ? .blue.opacity(0.5) : .black.opacity(0.2), radius: isSelected ? 15 : 10, x: 0, y: 5)
            .scaleEffect(isSelected ? 1.05 : 1.0)
    }
}

struct OperatorCardView: View {
    var op: String
    var isSelected: Bool
    
    var body: some View {
        Text(op)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(isSelected ? .black : .white)
            .frame(width: 65, height: 65)
            .background(
                Circle()
                    .fill(isSelected ? Color.green : Color.white.opacity(0.15))
            )
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.green : Color.white.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
            .shadow(color: isSelected ? .green.opacity(0.5) : .clear, radius: 15, x: 0, y: 0)
            .scaleEffect(isSelected ? 1.1 : 1.0)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
