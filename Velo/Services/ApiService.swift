//
//  ApiService.swift
//  Velo
//
//  Centralized API manager for Velo services
//

import Foundation

class ApiService {
    static let shared = ApiService()
    
    private let baseURL = "https://velo.3zozz.com/api/v1"
    private let urlSession = URLSession.shared
    
    private init() {}
    
    // MARK: - AI Models
    
    func fetchAIModels() async throws -> [AIModelConfig] {
        guard let url = URL(string: "\(baseURL)/models") else {
            throw ApiError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ApiError.serverError
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let apiResponse = try decoder.decode(VeloApiResponse<[AIModelConfig]>.self, from: data)
        return apiResponse.data
    }
}

// MARK: - Models

struct VeloApiResponse<T: Codable>: Codable {
    let data: T
    let success: Bool
    let message: String
    let requestedAt: String
}

struct AIModelConfig: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let endpoint: String
    let model: String
    let description: String
}

enum ApiError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .serverError: return "Velu API server error."
        case .decodingError: return "Failed to process server response."
        }
    }
}
