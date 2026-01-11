//
//  ApiService.swift
//  Velo
//
//  Centralized API manager for Velo services
//

import Foundation

class ApiService {
    static let shared = ApiService()
    
    let appVersion = "1.0.0"
    private let baseURL = "https://velo.3zozz.com/api/v1"
    private let urlSession = URLSession.shared
    
    private init() {}
    
    // MARK: - Actions
    
    func fetchAIModels() async throws -> [AIModelConfig] {
        let (data, _) = try await performRequest(endpoint: "/models")
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let apiResponse = try decoder.decode(VeloApiResponse<[AIModelConfig]>.self, from: data)
            return apiResponse.data
        } catch {
            throw ApiError.decodingError
        }
    }
    
    func checkForUpdates() async throws -> VeloUpdateInfo {
        let (data, _) = try await performRequest(endpoint: "/updates/check")
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let apiResponse = try decoder.decode(VeloUpdateResponse.self, from: data)
            return apiResponse.update
        } catch {
            throw ApiError.decodingError
        }
    }
    
    // MARK: - Core Request Logic
    
    private func performRequest(endpoint: String) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw ApiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(appVersion, forHTTPHeaderField: "X-Velo-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.serverError
        }
        
        // Handle 426 Upgrade Required
        if httpResponse.statusCode == 426 {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Try to decode the 426 error response
            if let errorResponse = try? decoder.decode(UpdateRequiredResponse.self, from: data) {
                // Convert to VeloUpdateInfo for the overlay
                let updateInfo = VeloUpdateInfo(
                    latestVersion: errorResponse.latestVersion,
                    pageUpdate: "https://velo.3zozz.com/",
                    releaseNotes: errorResponse.message,
                    isRequired: errorResponse.updateRequired,
                    releaseDate: errorResponse.requestedAt
                )
                
                NotificationCenter.default.post(name: .requiredUpdateDetected, object: updateInfo)
                throw ApiError.updateRequired(updateInfo)
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ApiError.serverError
        }
        
        return (data, httpResponse)
    }
}

// MARK: - Models

struct VeloApiResponse<T: Codable>: Codable {
    let data: T
    let success: Bool
    let message: String
    let requestedAt: String
}

struct VeloUpdateResponse: Codable {
    let update: VeloUpdateInfo
    let success: Bool
    let message: String
    let requestedAt: String
}

// Response for 426 Upgrade Required errors
struct UpdateRequiredResponse: Codable {
    let success: Bool
    let message: String
    let updateRequired: Bool
    let latestVersion: String
    let requestedAt: String
}

struct VeloUpdateInfo: Codable, Equatable {
    let latestVersion: String
    let pageUpdate: String
    let releaseNotes: String
    let isRequired: Bool
    let releaseDate: String
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
    case updateRequired(VeloUpdateInfo)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .serverError: return "Velo API server error."
        case .decodingError: return "Failed to process server response."
        case .updateRequired(let info): return "Update Required: v\(info.latestVersion) is available."
        }
    }
}

extension Notification.Name {
    static let requiredUpdateDetected = Notification.Name("requiredUpdateDetected")
}
