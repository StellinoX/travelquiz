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
    @Published var shouldNavigateToHome = false  // Triggers navigation back to home
    
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
            
            print("✅ Room created: \(result.room_id), PIN: \(result.pin)")
            
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
            
            // Set currentPlayer for host
            if let hostPlayer = players.first(where: { $0.is_host }) {
                currentPlayer = hostPlayer
                print("👑 Host player set: \(hostPlayer.name)")
            }
            
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
            let params: [String: AnyJSON] = [
                "p_pin": try AnyJSON(pin),
                "p_player_name": try AnyJSON(playerName)
            ]
            
            let response: [JoinRoomResponse] = try await supabase
                .rpc("join_room", params: params)
                .execute()
                .value
            
            guard let result = response.first else {
                errorMessage = "Failed to join room"
                isLoading = false
                return false
            }
            
            print("✅ Joined room: \(result.room_id)")
            
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
            
            print("👥 Fetched \(response.count) players")
            players = response
        } catch {
            print("❌ Error fetching players: \(error)")
        }
    }
    
    // MARK: - Check Room Status (for polling)
    func checkRoomStatus(roomId: Int) async {
        do {
            let rooms: [Room] = try await supabase
                .from("rooms")
                .select()
                .eq("id", value: roomId)
                .execute()
                .value
            
            if let room = rooms.first,
               (room.status != currentRoom?.status ||
                room.current_question_index != currentRoom?.current_question_index) {
                print("🔄 Room updated - status: \(room.status), question: \(room.current_question_index ?? 0)")
                currentRoom = room
            }
        } catch {
            print("❌ Error checking room status: \(error)")
        }
    }
    
    // MARK: - Start Quiz
    func startQuiz() async {
        guard let roomId = currentRoom?.id else { return }
        
        do {
            let updateData: [String: AnyJSON] = [
                "status": try AnyJSON("active"),
                "current_question_index": try AnyJSON(0)
            ]
            
            try await supabase
                .from("rooms")
                .update(updateData)
                .eq("id", value: roomId)
                .execute()
            
            print("✅ Quiz started for room: \(roomId)")
            
            // Update local room status
            if let room = currentRoom {
                currentRoom = Room(
                    id: room.id,
                    pin: room.pin,
                    subtopic_id: room.subtopic_id,
                    status: "active",
                    current_question_index: 0,
                    created_at: room.created_at
                )
            }
        } catch {
            errorMessage = "Failed to start quiz: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Submit Answer
    func submitAnswer(questionId: Int, choiceId: Int, answerTime: Double) async -> (isCorrect: Bool, points: Int)? {
        guard let roomId = currentRoom?.id,
              let playerId = currentPlayer?.id else { return nil }
        
        do {
            struct SubmitAnswerResponse: Codable {
                let is_correct: Bool
                let points_earned: Int
            }
            
            let params: [String: AnyJSON] = [
                "p_room_id": try AnyJSON(roomId),
                "p_player_id": try AnyJSON(playerId),
                "p_question_id": try AnyJSON(questionId),
                "p_choice_id": try AnyJSON(choiceId),
                "p_answer_time": try AnyJSON(answerTime)
            ]
            
            let response: [SubmitAnswerResponse] = try await supabase
                .rpc("submit_answer", params: params)
                .execute()
                .value
            
            if let result = response.first {
                print("✅ Answer submitted: correct=\(result.is_correct), points=\(result.points_earned)")
                
                // Refresh players to update scores
                await fetchPlayers(roomId: roomId)
                
                return (result.is_correct, result.points_earned)
            }
            
            return nil
        } catch {
            print("❌ Error submitting answer: \(error)")
            return nil
        }
    }
    
    // MARK: - Next Question (Host only)
    func nextQuestion() async {
        guard let roomId = currentRoom?.id else { return }
        
        do {
            let params: [String: AnyJSON] = [
                "p_room_id": try AnyJSON(roomId)
            ]
            
            let response: [Int] = try await supabase
                .rpc("next_question", params: params)
                .execute()
                .value
            
            if let newIndex = response.first {
                print("➡️ Advanced to question: \(newIndex)")
                
                // Update local room
                if let room = currentRoom {
                    currentRoom = Room(
                        id: room.id,
                        pin: room.pin,
                        subtopic_id: room.subtopic_id,
                        status: room.status,
                        current_question_index: newIndex,
                        created_at: room.created_at
                    )
                }
                
                // Refresh players
                await fetchPlayers(roomId: roomId)
            }
        } catch {
            print("❌ Error advancing question: \(error)")
        }
    }
    
    // MARK: - Finish Quiz
    func finishQuiz() async {
        guard let roomId = currentRoom?.id else { return }
        
        do {
            let updateData: [String: AnyJSON] = [
                "status": try AnyJSON("finished")
            ]
            
            try await supabase
                .from("rooms")
                .update(updateData)
                .eq("id", value: roomId)
                .execute()
            
            print("🏁 Quiz finished for room: \(roomId)")
            
            // Update local room status
            if let room = currentRoom {
                currentRoom = Room(
                    id: room.id,
                    pin: room.pin,
                    subtopic_id: room.subtopic_id,
                    status: "finished",
                    current_question_index: room.current_question_index,
                    created_at: room.created_at
                )
            }
            
            // Fetch final scores
            await fetchPlayers(roomId: roomId)
        } catch {
            print("❌ Error finishing quiz: \(error)")
        }
    }
    
    // MARK: - Get Leaderboard
    func getLeaderboard() -> [LeaderboardEntry] {
        let sortedPlayers = players.sorted { $0.score > $1.score }
        
        let colors = ["blue", "purple", "green", "orange", "pink", "red", "yellow", "cyan"]
        
        return sortedPlayers.enumerated().map { index, player in
            LeaderboardEntry(
                id: player.id,
                playerName: player.name,
                score: player.score,
                rank: index + 1,
                isCurrentUser: player.id == currentPlayer?.id,
                avatarColor: colors[index % colors.count]
            )
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
            
            print("❓ Fetched \(response.count) questions")
            questions = response
            isLoading = false
        } catch {
            errorMessage = "Failed to load questions: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Realtime Subscription
    func subscribeToRoom(roomId: Int) {
        print("🔌 Subscribing to room: \(roomId)")
        
        // Remove existing subscription
        if let channel = realtimeChannel {
            Task {
                await supabase.removeChannel(channel)
            }
        }
        
        let channel = supabase.channel("room-\(roomId)")
        
        // Subscribe to players changes
        channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "players",
            filter: "room_id=eq.\(roomId)"
        ) { [weak self] payload in
            print("👥 Players table changed: \(payload)")
            guard let self = self else { return }
            Task { @MainActor in
                await self.fetchPlayers(roomId: roomId)
            }
        }
        
        // Subscribe to room status changes
        channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "rooms",
            filter: "id=eq.\(roomId)"
        ) { [weak self] action in
            print("🏠 Room table changed: \(action)")
            guard let self = self else { return }
            Task { @MainActor in
                await self.checkRoomStatus(roomId: roomId)
            }
        }
        
        realtimeChannel = channel
        
        Task {
            await channel.subscribe()
            print("✅ Subscribed to room: \(roomId)")
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
