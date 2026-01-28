//
//  HostFlowView.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//


import SwiftUI

struct HostFlowView: View {
    @EnvironmentObject var viewModel: QuizViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var hostName = ""
    @State private var selectedTopic: Topic?
    @State private var selectedSubtopic: Subtopic?
    @State private var showSubtopicPicker = false
    @State private var roomPIN: String?
    @State private var showWaitingRoom = false
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            if roomPIN != nil {
                // Waiting room
                WaitingRoomView(isHost: true)
                    .environmentObject(viewModel)
            } else {
                // Setup screen
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Host a Quiz")
                                .font(.largeTitle.bold())
                        }
                        .padding(.top, 20)
                        
                        // Name input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Name")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter your name", text: $hostName)
                                .textFieldStyle(.roundedBorder)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // City selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose a City")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if viewModel.isLoading && viewModel.topics.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                ForEach(viewModel.topics) { topic in
                                    CityCard(
                                        topic: topic,
                                        isSelected: selectedTopic?.id == topic.id
                                    ) {
                                        selectedTopic = topic
                                        selectedSubtopic = nil
                                        showSubtopicPicker = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Selected subtopic display
                        if let subtopic = selectedSubtopic {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Category")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(subtopic.name)
                                            .font(.headline)
                                        if let desc = subtopic.description {
                                            Text(desc)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Change") {
                                        showSubtopicPicker = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Error message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        
                        // Create button
                        Button {
                            Task {
                                await createRoom()
                            }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.6))
                                    .cornerRadius(16)
                            } else {
                                Text("Create Room")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        canCreateRoom ? Color.blue : Color.gray.opacity(0.3)
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                        }
                        .disabled(!canCreateRoom || viewModel.isLoading)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSubtopicPicker) {
            if let topic = selectedTopic {
                SubtopicPickerView(
                    topic: topic,
                    selectedSubtopic: $selectedSubtopic,
                    isPresented: $showSubtopicPicker
                )
            }
        }
        .task {
            if viewModel.topics.isEmpty {
                await viewModel.fetchTopics()
            }
        }
    }
    
    var canCreateRoom: Bool {
        !hostName.isEmpty && selectedSubtopic != nil
    }
    
    func createRoom() async {
        guard let subtopicId = selectedSubtopic?.id else { return }
        
        if let pin = await viewModel.createRoom(
            subtopicId: subtopicId,
            hostName: hostName
        ) {
            roomPIN = pin
        }
    }
}

// MARK: - City Card
struct CityCard: View {
    let topic: Topic
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.city)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    Text(topic.country)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Subtopic Picker
struct SubtopicPickerView: View {
    let topic: Topic
    @Binding var selectedSubtopic: Subtopic?
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(topic.subtopics ?? []) { subtopic in
                    Button {
                        selectedSubtopic = subtopic
                        isPresented = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subtopic.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let desc = subtopic.description {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedSubtopic?.id == subtopic.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
