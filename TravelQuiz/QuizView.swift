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
    
    @State private var currentQuestionIndex = 0
    @State private var selectedChoice: Choice?
    @State private var showResult = false
    @State private var timeRemaining = 20
    @State private var timer: Timer?
    
    var currentQuestion: Question? {
        guard currentQuestionIndex < viewModel.questions.count else { return nil }
        return viewModel.questions[currentQuestionIndex]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if let question = currentQuestion {
                VStack(spacing: 24) {
                    // Progress bar
                    HStack(spacing: 8) {
                        ForEach(0..<viewModel.questions.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index <= currentQuestionIndex ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 6)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
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
                                if !showResult {
                                    selectedChoice = choice
                                    checkAnswer()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Next button
                    if showResult {
                        Button {
                            nextQuestion()
                        } label: {
                            Text(currentQuestionIndex < viewModel.questions.count - 1 ? "Next Question" : "Finish")
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
            } else {
                // Quiz finished
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Quiz Complete!")
                        .font(.largeTitle.bold())
                    
                    Button("Back to Home") {
                        viewModel.leaveRoom()
                        dismiss()
                    }
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    func startTimer() {
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
                    checkAnswer()
                }
            }
        }
    }
    
    func checkAnswer() {
        showResult = true
        timer?.invalidate()
        
        // Add haptic feedback
        if selectedChoice?.is_correct == true {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    func nextQuestion() {
        currentQuestionIndex += 1
        selectedChoice = nil
        showResult = false
        
        if currentQuestion != nil {
            startTimer()
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
