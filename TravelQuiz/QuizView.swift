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
    
    var allPlayersAnswered: Bool {
        viewModel.players.allSatisfy { $0.has_answered == true }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if viewModel.currentRoom?.status == "finished" || currentQuestion == nil {
                // Show leaderboard
                LeaderboardView()
                    .environmentObject(viewModel)
                    .onAppear {
                        timer?.invalidate()
                    }
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
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(timeRemaining) / CGFloat(question.time_limit_sec))
                            .stroke(
                                timeRemaining > 5 ? Color.green : Color.red,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timeRemaining)
                        
                        Text("\(timeRemaining)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                    }
                    .padding(.top, 20)
                    
                    // Question
                    Text(question.prompt)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    // Choices
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
                    
                    Spacer()
                    
                    // Result feedback
                    if showResult {
                        VStack(spacing: 12) {
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
                            
                            // Waiting message
                            if !allPlayersAnswered {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Waiting for other players...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    
                    // Next button (host only, when all answered or time up)
                    if isHost && (allPlayersAnswered || timeRemaining == 0) {
                        Button {
                            advanceToNextQuestion()
                        } label: {
                            Text(currentQuestionIndex < viewModel.questions.count - 1 ? "Next Question" : "Finish Quiz")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: currentQuestionIndex) { oldValue, newValue in
            if oldValue != newValue {
                resetForNewQuestion()
            }
        }
        .onAppear {
            resetForNewQuestion()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    func resetForNewQuestion() {
        selectedChoice = nil
        showResult = false
        answerStartTime = Date()
        
        guard let question = currentQuestion else { return }
        timeRemaining = question.time_limit_sec
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Time's up
                timer?.invalidate()
                if !showResult {
                    // Auto-submit with no answer
                    autoSubmitOnTimeout()
                }
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
                timer?.invalidate()
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(result.isCorrect ? .success : .error)
            }
        }
    }
    
    func autoSubmitOnTimeout() {
        guard let question = currentQuestion else { return }
        
        // Submit with first choice (will be marked incorrect)
        if let firstChoice = question.choices.first {
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
    }
    
    func advanceToNextQuestion() {
        if currentQuestionIndex < viewModel.questions.count - 1 {
            Task {
                await viewModel.nextQuestion()
            }
        } else {
            // Finish quiz
            Task {
                await viewModel.finishQuiz()
            }
        }
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
            HStack {
                Text(choice.label)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if showResult {
                    if choice.is_correct {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if isSelected {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
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
