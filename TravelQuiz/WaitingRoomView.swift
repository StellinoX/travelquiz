//
//  WaitingRoomView.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//



import SwiftUI

struct WaitingRoomView: View {
    @EnvironmentObject var viewModel: QuizViewModel
    @Environment(\.dismiss) var dismiss
    
    let isHost: Bool
    @State private var showStartConfirmation = false
    @State private var navigateToQuiz = false
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // PIN Display
                VStack(spacing: 12) {
                    Text("Room PIN")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.currentRoom?.pin ?? "------")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                }
                .padding(.top, 40)
                
                // Players list
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Players")
                            .font(.title2.bold())
                        
                        Spacer()
                        
                        Text("\(viewModel.players.count)")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.players) { player in
                                PlayerRow(player: player)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Start button (host only)
                if isHost {
                    Button {
                        showStartConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Quiz")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.players.count >= 1 ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(viewModel.players.count < 1)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.leaveRoom()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Leave")
                    }
                }
            }
        }
        .alert("Start Quiz?", isPresented: $showStartConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Start") {
                Task {
                    // Load questions first
                    if let subtopicId = viewModel.currentRoom?.subtopic_id {
                        await viewModel.fetchQuestions(subtopicId: subtopicId)
                    }
                    await viewModel.startQuiz()
                }
            }
        } message: {
            Text("All players will begin the quiz.")
        }
        .navigationDestination(isPresented: $navigateToQuiz) {
            QuizView()
                .environmentObject(viewModel)
        }
        .onChange(of: viewModel.currentRoom?.status) { newValue in
            if newValue == "active" {
                // Load questions if not already loaded
                if viewModel.questions.isEmpty, let subtopicId = viewModel.currentRoom?.subtopic_id {
                    Task {
                        await viewModel.fetchQuestions(subtopicId: subtopicId)
                        navigateToQuiz = true
                    }
                } else {
                    navigateToQuiz = true
                }
            }
        }
    }
}

// MARK: - Player Row
struct PlayerRow: View {
    let player: Player
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(player.is_host ? Color.blue : Color.purple)
                .frame(width: 50, height: 50)
                .overlay {
                    Text(String(player.name.prefix(1)).uppercased())
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            
            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.headline)
                
                if player.is_host {
                    Text("Host")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Host badge
            if player.is_host {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        WaitingRoomView(isHost: true)
            .environmentObject(QuizViewModel())
    }
}
