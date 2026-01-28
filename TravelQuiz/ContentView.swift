//
//  ContentView.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = QuizViewModel()
    @State private var navigateToHost = false
    @State private var navigateToJoin = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Logo/Title
                    VStack(spacing: 12) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Travel Quiz")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        
                        Text("Test your city knowledge")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 16) {
                        // Host button
                        Button {
                            navigateToHost = true
                        } label: {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .font(.title3)
                                Text("Host Quiz")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        
                        // Join button
                        Button {
                            navigateToJoin = true
                        } label: {
                            HStack {
                                Image(systemName: "person.fill.checkmark")
                                    .font(.title3)
                                Text("Join Quiz")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }
            }
            .navigationDestination(isPresented: $navigateToHost) {
                HostFlowView()
                    .environmentObject(viewModel)
            }
            .navigationDestination(isPresented: $navigateToJoin) {
                JoinRoomView()
                    .environmentObject(viewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
