//
//  SupabaseManager.swift
//  TravelQuiz
//
//  Created by Alberto Estrada on 28/01/26.
//


import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // REEMPLAZA ESTOS VALORES CON TUS CREDENCIALES
        let supabaseURL = "https://yfglqfpvznaayibzgalz.supabase.co"
        let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmZ2xxZnB2em5hYXlpYnpnYWx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1OTEyMTksImV4cCI6MjA4NTE2NzIxOX0.ANz-CiXFvVDfJBe3eUqAWrW92PnXM77r7jq9prXdf14"
        
        self.client = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseAnonKey
        )
    }
}
