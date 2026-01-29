//
//  QuizView.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//

import SwiftUI

struct QuizView: View {
    @EnvironmentObject var viewModel: QuizViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedChoice: Choice?
    @State private var showResult = false
    @State private var timeRemaining = 20
    @State private var timer: Timer?
    @State private var answerStartTime: Date?
    @State private var earnedPoints: Int = 0
    @State private var showIntermediateRanking = false
    @State private var hasAdvanced = false
    
    var currentQuestionIndex: Int {
        viewModel.currentRoom?.current_question_index ?? 0
    }
    
    var currentQuestion: Question? {
        guard currentQuestionIndex < viewModel.questions.count else { return nil }
        return viewModel.questions[currentQuestionIndex]
    }
    
    var isHost: Bool {
        viewModel.currentPlayer?.is_host ?? false
    }
    
    var answeredPlayers: [Player] {
        viewModel.players.filter { $0.has_answered == true }
    }
    
    var allPlayersAnswered: Bool {
        let totalPlayers = viewModel.players.count
        let answeredCount = answeredPlayers.count
        return totalPlayers > 0 && answeredCount == totalPlayers
    }
    
    var isLastQuestion: Bool {
        currentQuestionIndex >= viewModel.questions.count - 1
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if viewModel.currentRoom?.status == "finished" {
                // Show final leaderboard
                LeaderboardView()
                    .environmentObject(viewModel)
                    .onAppear {
                        timer?.invalidate()
                        playerPollingTimer?.invalidate()
                    }
            } else if showIntermediateRanking {
                // Show intermediate ranking (NOT on last question)
                IntermediateRankingView(
                    leaderboard: viewModel.getLeaderboard()
                )
                .transition(.opacity)
            } else if let question = currentQuestion {
                VStack(spacing: 24) {
                    // Progress bar
                    HStack(spacing: 8) {
                        ForEach(0..<viewModel.questions.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index < currentQuestionIndex ? Color.green :
                                      index == currentQuestionIndex ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 6)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Question counter
                    Text("Question \(currentQuestionIndex + 1) of \(viewModel.questions.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Timer
                    TimerCircle(
                        timeRemaining: timeRemaining,
                        totalTime: question.time_limit_sec
                    )
                    .padding(.top, 20)
                    
                    // Question
                    ScrollView {
                        Text(question.prompt)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 100)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Choices
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(question.choices) { choice in
                                ChoiceButton(
                                    choice: choice,
                                    isSelected: selectedChoice?.id == choice.id,
                                    showResult: showResult
                                ) {
                                    if !showResult && answerStartTime != nil {
                                        selectedChoice = choice
                                        submitAnswer(choice: choice)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Result feedback + Player bubbles
                    VStack(spacing: 16) {
                        if showResult {
                            if selectedChoice?.is_correct == true {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Correct! +\(earnedPoints) points")
                                        .font(.headline)
                                }
                                .padding()
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(12)
                            } else {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(selectedChoice == nil ? "Time's up!" : "Incorrect")
                                        .font(.headline)
                                }
                                .padding()
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Player answer bubbles
                        if !answeredPlayers.isEmpty {
                            PlayerAnswerBubbles(players: answeredPlayers)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .transition(.opacity)
                .id("question-\(currentQuestionIndex)") // Force view refresh
            }
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: currentQuestionIndex) { oldValue, newValue in
            if oldValue != newValue {
                resetForNewQuestion()
            }
        }
        .onChange(of: timeRemaining) { oldValue, newValue in
            if newValue == 0 && oldValue == 1 && !hasAdvanced {
                handleTimeUp()
            }
        }
        .onChange(of: allPlayersAnswered) { oldValue, newValue in
            if newValue && !oldValue && !hasAdvanced {
                print("✅ All players answered! Advancing...")
                handleAllPlayersAnswered()
            }
        }
        .onAppear {
            resetForNewQuestion()
            startPlayerPolling()
        }
        .onDisappear {
            timer?.invalidate()
            playerPollingTimer?.invalidate()
        }
    }
    
    @State private var playerPollingTimer: Timer?
    
    private func startPlayerPolling() {
        playerPollingTimer?.invalidate()
        
        playerPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if let roomId = viewModel.currentRoom?.id {
                    await viewModel.fetchPlayers(roomId: roomId)
                    await viewModel.checkRoomStatus(roomId: roomId)
                }
            }
        }
        
        if let timer = playerPollingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func resetForNewQuestion() {
        selectedChoice = nil
        showResult = false
        answerStartTime = Date()
        hasAdvanced = false
        
        guard let question = currentQuestion else { return }
        timeRemaining = question.time_limit_sec
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
    
    func submitAnswer(choice: Choice) {
        guard let startTime = answerStartTime,
              let question = currentQuestion else { return }
        
        let answerTime = Date().timeIntervalSince(startTime)
        
        Task {
            if let result = await viewModel.submitAnswer(
                questionId: question.id,
                choiceId: choice.id,
                answerTime: answerTime
            ) {
                showResult = true
                earnedPoints = result.points
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(result.isCorrect ? .success : .error)
            }
        }
    }
    
    func handleAllPlayersAnswered() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        
        timer?.invalidate()
        
        if !showResult {
            guard let question = currentQuestion,
                  let firstChoice = question.choices.first else { return }
            
            Task {
                let _ = await viewModel.submitAnswer(
                    questionId: question.id,
                    choiceId: firstChoice.id,
                    answerTime: Double(question.time_limit_sec) - Double(timeRemaining)
                )
                showResult = true
                earnedPoints = 0
            }
        }
        
        Task {
            // Espera 1.5 segundos
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // Si NO es la última pregunta, muestra ranking
            if !isLastQuestion {
                showIntermediateRanking = true
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 segundos de ranking
            }
            
            // Avanza (host actualiza DB)
            if isHost {
                if !isLastQuestion {
                    await viewModel.nextQuestion()
                } else {
                    await viewModel.finishQuiz()
                }
            }
            
            showIntermediateRanking = false
        }
    }
    
    func handleTimeUp() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        
        if !showResult {
            guard let question = currentQuestion,
                  let firstChoice = question.choices.first else { return }
            
            Task {
                let _ = await viewModel.submitAnswer(
                    questionId: question.id,
                    choiceId: firstChoice.id,
                    answerTime: Double(question.time_limit_sec)
                )
                showResult = true
                earnedPoints = 0
            }
        }
        
        Task {
            // Espera 1.5 segundos
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            // Si NO es la última pregunta, muestra ranking
            if !isLastQuestion {
                showIntermediateRanking = true
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 segundos
            }
            
            // Avanza
            if isHost {
                if !isLastQuestion {
                    await viewModel.nextQuestion()
                } else {
                    await viewModel.finishQuiz()
                }
            }
            
            showIntermediateRanking = false
        }
    }
}

// MARK: - Timer Circle Component
struct TimerCircle: View {
    let timeRemaining: Int
    let totalTime: Int
    
    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(timeRemaining) / Double(totalTime)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                .frame(width: 80, height: 80)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    timeRemaining > 5 ? Color.green : Color.red,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
            
            Text("\(timeRemaining)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - Player Answer Bubbles
struct PlayerAnswerBubbles: View {
    let players: [Player]
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(players) { player in
                Circle()
                    .fill(player.is_host ? Color.blue : Color.purple)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(player.name.prefix(1)).uppercased())
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: players.count)
        .padding(.horizontal)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.positions = positions
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Intermediate Ranking View
struct IntermediateRankingView: View {
    let leaderboard: [LeaderboardEntry]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Current Rankings")
                        .font(.title.bold())
                }
                .padding(.top, 40)
                
                // Rankings with animation
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(leaderboard) { entry in
                            AnimatedRankingRow(entry: entry)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .id(entry.id) // Force view update on rank change
                        }
                    }
                    .padding(.horizontal)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: leaderboard.map { $0.rank })
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Animated Ranking Row
struct AnimatedRankingRow: View {
    let entry: LeaderboardEntry
    
    var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    var avatarColor: Color {
        switch entry.avatarColor {
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "red": return .red
        case "yellow": return .yellow
        case "cyan": return .cyan
        default: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text("#\(entry.rank)")
                .font(.title2.bold())
                .foregroundColor(rankColor)
                .frame(width: 50)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: entry.rank)
            
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: 45, height: 45)
                .overlay {
                    Text(String(entry.playerName.prefix(1)).uppercased())
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.playerName)
                    .font(.headline)
                    .foregroundColor(entry.isCurrentUser ? .blue : .primary)
                    .lineLimit(1)
                
                if entry.isCurrentUser {
                    Text("You")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Score with animation
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.score)")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: entry.score)
                
                Text("pts")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(entry.isCurrentUser ? Color.blue.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(entry.isCurrentUser ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Choice Button
struct ChoiceButton: View {
    let choice: Choice
    let isSelected: Bool
    let showResult: Bool
    let action: () -> Void
    
    var backgroundColor: Color {
        if !showResult {
            return isSelected ? Color.blue.opacity(0.2) : Color.white
        }
        
        if choice.is_correct {
            return Color.green.opacity(0.3)
        } else if isSelected && !choice.is_correct {
            return Color.red.opacity(0.3)
        }
        
        return Color.white
    }
    
    var borderColor: Color {
        if !showResult {
            return isSelected ? Color.blue : Color.clear
        }
        
        if choice.is_correct {
            return Color.green
        } else if isSelected && !choice.is_correct {
            return Color.red
        }
        
        return Color.clear
    }
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text(choice.label)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 8)
                
                if showResult {
                    if choice.is_correct {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .disabled(showResult)
    }
}
