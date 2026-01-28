//
//  JoinRoomView.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//


import SwiftUI

struct JoinRoomView: View {
    @EnvironmentObject var viewModel: QuizViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var pin = ""
    @State private var playerName = ""
    @State private var joinedRoom = false
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            if joinedRoom {
                WaitingRoomView(isHost: false)
                    .environmentObject(viewModel)
            } else {
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "door.right.hand.open")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                            
                            Text("Join Quiz")
                                .font(.largeTitle.bold())
                            
                            Text("Enter the room PIN to join")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // PIN input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Room PIN")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter 6-digit PIN", text: $pin)
                                .keyboardType(.numberPad)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .onChange(of: pin) { newValue in
                                    // Limit to 6 digits
                                    if newValue.count > 6 {
                                        pin = String(newValue.prefix(6))
                                    }
                                    // Only allow numbers
                                    pin = pin.filter { $0.isNumber }
                                }
                        }
                        .padding(.horizontal)
                        
                        // Name input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Name")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter your nickname", text: $playerName)
                                .textFieldStyle(.roundedBorder)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Error message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        
                        // Join button
                        Button {
                            Task {
                                await joinRoom()
                            }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple.opacity(0.6))
                                    .cornerRadius(16)
                            } else {
                                Text("Join Room")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        canJoin ? Color.purple : Color.gray.opacity(0.3)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        }
                        .disabled(!canJoin || viewModel.isLoading)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var canJoin: Bool {
        pin.count == 6 && !playerName.isEmpty
    }
    
    func joinRoom() async {
        let success = await viewModel.joinRoom(pin: pin, playerName: playerName)
        if success {
            joinedRoom = true
        }
    }
}
