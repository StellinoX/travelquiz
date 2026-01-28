//
//  LeaderboardView.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//

import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var viewModel: QuizViewModel
    @Environment(\.dismiss) var dismiss
    
    var leaderboard: [LeaderboardEntry] {
        viewModel.getLeaderboard()
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Trophy icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 40)
                
                Text("Quiz Complete!")
                    .font(.largeTitle.bold())
                
                // Leaderboard
                VStack(alignment: .leading, spacing: 0) {
                    Text("Final Rankings")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(leaderboard) { entry in
                                LeaderboardRow(entry: entry)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .frame(maxHeight: 400)
                
                Spacer()
                
                // Back to home button
                Button {
                    viewModel.leaveRoom()
                    // Dismiss all the way to root
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        rootVC.dismiss(animated: true)
                    }
                } label: {
                    HStack {
                        Image(systemName: "house.fill")
                        Text("Back to Home")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    
    var rankColor: Color {
        switch entry.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    var rankIcon: String {
        switch entry.rank {
        case 1: return "crown.fill"
        case 2: return "2.circle.fill"
        case 3: return "3.circle.fill"
        default: return "\(entry.rank).circle"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank icon
            Image(systemName: rankIcon)
                .font(.title2)
                .foregroundColor(rankColor)
                .frame(width: 40)
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.playerName)
                    .font(.headline)
                    .foregroundColor(entry.isCurrentUser ? .blue : .primary)
                
                if entry.isCurrentUser {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Score
            Text("\(entry.score)")
                .font(.title3.bold())
                .foregroundColor(.primary)
            
            Text("pts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(entry.isCurrentUser ? Color.blue.opacity(0.1) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(entry.isCurrentUser ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(QuizViewModel())
}
