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
            print("✅ [API] Successfully decoded \(apiResponse.data.count) AI models")
            return apiResponse.data
        } catch {
            print("❌ [API] Failed to decode AI models: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [API] Raw response: \(responseString)")
            }
            throw ApiError.decodingError
        }
    }
    
    func checkForUpdates() async throws -> VeloUpdateInfo {
        let (data, _) = try await performRequest(endpoint: "/updates/check")
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let apiResponse = try decoder.decode(VeloUpdateResponse.self, from: data)
            print("✅ [API] Successfully decoded update info: v\(apiResponse.update.latestVersion)")
            return apiResponse.update
        } catch {
            print("❌ [API] Failed to decode update response: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [API] Raw response: \(responseString)")
            }
            throw ApiError.decodingError
        }
    }
    
    // MARK: - Core Request Logic
    
    private func performRequest(endpoint: String) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            print("❌ [API] Invalid URL: \(baseURL)\(endpoint)")
            throw ApiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(appVersion, forHTTPHeaderField: "X-Velo-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("📤 [API] Request: \(request.httpMethod ?? "GET") \(url)")
        print("📤 [API] Headers: X-Velo-Version: \(appVersion)")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [API] Invalid response type")
            throw ApiError.serverError
        }
        
        print("📥 [API] Response Status: \(httpResponse.statusCode)")
        
        // Log response body for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 [API] Response Body: \(responseString)")
        } else {
            print("📥 [API] Response Body: (unable to decode as string)")
        }
        
        // Handle 426 Upgrade Required
        if httpResponse.statusCode == 426 {
            print("⚠️ [API] Update required (426)")
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let updateInfo = try? decoder.decode(VeloUpdateResponse.self, from: data) {
                NotificationCenter.default.post(name: .requiredUpdateDetected, object: updateInfo.update)
                throw ApiError.updateRequired(updateInfo.update)
            }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ [API] Server error: status \(httpResponse.statusCode)")
            throw ApiError.serverError
        }
        
        print("✅ [API] Request successful")
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
