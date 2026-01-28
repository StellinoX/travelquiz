//
//  QuizViewModel.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//


import Foundation
import Combine
import Supabase

@MainActor
class QuizViewModel: ObservableObject {
    private let supabase = SupabaseManager.shared.client
    
    // Published properties
    @Published var topics: [Topic] = []
    @Published var players: [Player] = []
    @Published var questions: [Question] = []
    @Published var currentRoom: Room?
    @Published var currentPlayer: Player?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var realtimeChannel: RealtimeChannelV2?
    
    // MARK: - Fetch Topics with Subtopics
    func fetchTopics() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [Topic] = try await supabase
                .from("topics")
                .select("id, city, country, subtopics(id, name, description)")
                .order("city")
                .execute()
                .value
            
            topics = response
            isLoading = false
        } catch {
            errorMessage = "Failed to load topics: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Create Room (Host)
    func createRoom(subtopicId: Int, hostName: String) async -> String? {
        isLoading = true
        errorMessage = nil
        
        do {
            let params: [String: AnyJSON] = [
                "p_subtopic_id": try AnyJSON(subtopicId),
                "p_host_name": try AnyJSON(hostName)
            ]
            let response: [CreateRoomResponse] = try await supabase
                .rpc("create_room", params: params)
                .execute()
                .value
            
            guard let result = response.first else {
                errorMessage = "Failed to create room"
                isLoading = false
                return nil
            }
            
            // Fetch the created room
            let rooms: [Room] = try await supabase
                .from("rooms")
                .select()
                .eq("id", value: result.room_id)
                .execute()
                .value
            
            currentRoom = rooms.first
            
            // Subscribe to realtime
            subscribeToRoom(roomId: result.room_id)
            
            // Fetch initial players
            await fetchPlayers(roomId: result.room_id)
            
            isLoading = false
            return result.pin
            
        } catch {
            errorMessage = "Error creating room: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    // MARK: - Join Room (Player)
    func joinRoom(pin: String, playerName: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [JoinRoomResponse] = try await supabase
                .rpc("join_room", params: [
                    "p_pin": pin,
                    "p_player_name": playerName
                ])
                .execute()
                .value
            
            guard let result = response.first else {
                errorMessage = "Failed to join room"
                isLoading = false
                return false
            }
            
            // Fetch room details
            let rooms: [Room] = try await supabase
                .from("rooms")
                .select()
                .eq("id", value: result.room_id)
                .execute()
                .value
            
            currentRoom = rooms.first
            
            // Fetch player details
            let players: [Player] = try await supabase
                .from("players")
                .select()
                .eq("id", value: result.player_id)
                .execute()
                .value
            
            currentPlayer = players.first
            
            // Subscribe to realtime
            subscribeToRoom(roomId: result.room_id)
            
            // Fetch all players
            await fetchPlayers(roomId: result.room_id)
            
            isLoading = false
            return true
            
        } catch {
            if error.localizedDescription.contains("Invalid PIN") {
                errorMessage = "Room not found. Check the PIN."
            } else if error.localizedDescription.contains("already started") {
                errorMessage = "This quiz has already started."
            } else if error.localizedDescription.contains("already taken") {
                errorMessage = "This nickname is already taken."
            } else {
                errorMessage = "Error joining room: \(error.localizedDescription)"
            }
            isLoading = false
            return false
        }
    }
    
    // MARK: - Fetch Players
    func fetchPlayers(roomId: Int) async {
        do {
            let response: [Player] = try await supabase
                .from("players")
                .select()
                .eq("room_id", value: roomId)
                .order("created_at")
                .execute()
                .value
            
            players = response
        } catch {
            print("Error fetching players: \(error)")
        }
    }
    
    // MARK: - Start Quiz
    func startQuiz() async {
        guard let roomId = currentRoom?.id else { return }
        
        do {
            try await supabase
                .from("rooms")
                .update(["status": "active"])
                .eq("id", value: roomId)
                .execute()
            
            // Update local room status
            if var room = currentRoom {
                currentRoom = Room(
                    id: room.id,
                    pin: room.pin,
                    subtopic_id: room.subtopic_id,
                    status: "active",
                    created_at: room.created_at
                )
            }
        } catch {
            errorMessage = "Failed to start quiz: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Fetch Questions
    func fetchQuestions(subtopicId: Int) async {
        isLoading = true
        
        do {
            let response: [Question] = try await supabase
                .from("questions")
                .select("id, subtopic_id, prompt, time_limit_sec, choices(*)")
                .eq("subtopic_id", value: subtopicId)
                .order("id")
                .execute()
                .value
            
            questions = response
            isLoading = false
        } catch {
            errorMessage = "Failed to load questions: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Realtime Subscription
    func subscribeToRoom(roomId: Int) {
        // Remove existing subscription
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
        }
        
        let channel = supabase.channel("room-\(roomId)")
        
        // Subscribe to players changes
        let playersChanges = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "players",
            filter: "room_id=eq.\(roomId)"
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.fetchPlayers(roomId: roomId)
            }
        }
        
        // Subscribe to room status changes
        let roomChanges = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "rooms",
            filter: "id=eq.\(roomId)"
        ) { [weak self] action in
            guard let self = self else { return }
            Task { @MainActor in
                if let statusString = action.record["status"] as? String {
                    if var room = self.currentRoom {
                        self.currentRoom = Room(
                            id: room.id,
                            pin: room.pin,
                            subtopic_id: room.subtopic_id,
                            status: statusString,
                            created_at: room.created_at
                        )
                    }
                }
            }
        }
        
        realtimeChannel = channel
        
        Task {
            await channel.subscribe()
        }
    }
    
    // MARK: - Cleanup
    func leaveRoom() {
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
        }
        
        currentRoom = nil
        currentPlayer = nil
        players = []
        questions = []
        realtimeChannel = nil
    }
}
