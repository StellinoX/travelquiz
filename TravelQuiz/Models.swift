//
//  Models.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//

import Foundation

// MARK: - Topic (City)
struct Topic: Codable, Identifiable, Hashable {
    let id: Int
    let city: String
    let country: String
    let subtopics: [Subtopic]?
}

// MARK: - Subtopic (Category)
struct Subtopic: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String?
}

// MARK: - Room
struct Room: Codable, Identifiable {
    let id: Int
    let pin: String
    let subtopic_id: Int
    let status: String
    let current_question_index: Int?
    let created_at: String?
}

// MARK: - Player
struct Player: Codable, Identifiable {
    let id: Int
    let room_id: Int
    let name: String
    let score: Int
    let is_host: Bool
    let has_answered: Bool?
    let answer_time: Double?
    let created_at: String?
}

// MARK: - Question
struct Question: Codable, Identifiable {
    let id: Int
    let subtopic_id: Int
    let prompt: String
    let time_limit_sec: Int
    let choices: [Choice]
}

// MARK: - Choice
struct Choice: Codable, Identifiable {
    let id: Int
    let question_id: Int
    let label: String
    let is_correct: Bool
}

// MARK: - Answer Record
struct AnswerRecord: Codable, Identifiable {
    let id: Int?
    let room_id: Int
    let player_id: Int
    let question_id: Int
    let choice_id: Int
    let is_correct: Bool
    let answer_time: Double
    let points_earned: Int
    let created_at: String?
}

// MARK: - RPC Response Types
struct CreateRoomResponse: Codable {
    let room_id: Int
    let pin: String
    let subtopic_id: Int
    let topic_id: Int
}

struct JoinRoomResponse: Codable {
    let room_id: Int
    let player_id: Int
    let subtopic_id: Int
    let topic_id: Int
    let room_status: String
}

// MARK: - Leaderboard Entry
struct LeaderboardEntry: Identifiable, Equatable {
    let id: Int
    let playerName: String
    let score: Int
    let rank: Int
    let isCurrentUser: Bool
    let avatarColor: String // NEW: Color for avatar
    
    static func == (lhs: LeaderboardEntry, rhs: LeaderboardEntry) -> Bool {
        lhs.id == rhs.id && lhs.score == rhs.score && lhs.rank == rhs.rank
    }
}
