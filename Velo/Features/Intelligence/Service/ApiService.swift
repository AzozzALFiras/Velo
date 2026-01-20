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
            // API returns {"models": [...]} not {"data": [...]}
            let apiResponse = try decoder.decode(AIModelsResponse.self, from: data)
            print("[ApiService] ✅ Loaded \(apiResponse.models.count) AI models")
            return apiResponse.models
        } catch {
            print("[ApiService] AI Models Decoding Error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[ApiService] Received Data: \(jsonString.prefix(500))...")
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
            return apiResponse.update
        } catch {
            throw ApiError.decodingError
        }
    }
    
    func fetchCapabilities(category: String? = nil) async throws -> [Capability] {
        var endpoint = "/capabilities"
        if let category = category {
            endpoint += "?category=\(category)"
        }
        let (data, _) = try await performRequest(endpoint: endpoint)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let response = try decoder.decode(CapabilityListResponse.self, from: data)
            return response.data
        } catch {
            print("[ApiService] Capabilities Decoding Error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[ApiService] Received Data: \(jsonString.prefix(500))...")
            }
            throw ApiError.decodingError
        }
    }
    
    func fetchCapabilityDetails(slug: String) async throws -> Capability {
        let (data, _) = try await performRequest(endpoint: "/capabilities/\(slug)")
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            // Try wrapped response first ({"data": {...}})
            let response = try decoder.decode(CapabilityDetailResponse.self, from: data)
            print("[ApiService] ✅ Loaded capability details for \(slug)")
            return response.data
        } catch {
            // Fallback to direct decode
            do {
                let capability = try decoder.decode(Capability.self, from: data)
                print("[ApiService] ✅ Loaded capability details for \(slug) (direct)")
                return capability
            } catch {
                print("[ApiService] Capability Details Decoding Error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[ApiService] Received Data: \(jsonString.prefix(500))...")
                }
                throw ApiError.decodingError
            }
        }
    }
    
    func fetchCapabilityVersion(slug: String, version: String) async throws -> CapabilityVersion {
        let (data, _) = try await performRequest(endpoint: "/capabilities/\(slug)/\(version)")
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Try wrapped response first ({"data": {...}})
        struct VersionResponse: Codable {
            let data: CapabilityVersion
        }
        
        do {
            let response = try decoder.decode(VersionResponse.self, from: data)
            print("[ApiService] ✅ Loaded version details for \(slug)/\(version)")
            return response.data
        } catch {
            // Fallback to direct decode
            do {
                let versionDetail = try decoder.decode(CapabilityVersion.self, from: data)
                print("[ApiService] ✅ Loaded version details for \(slug)/\(version) (direct)")
                return versionDetail
            } catch {
                print("[ApiService] Capability Version Decoding Error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[ApiService] Received Data: \(jsonString.prefix(500))...")
                }
                throw ApiError.decodingError
            }
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

struct CapabilityListResponse: Codable {
    let data: [Capability]
    let meta: CapabilityMeta?
}

struct CapabilityMeta: Codable {
    let totalCapabilities: Int
}

struct CapabilityDetailResponse: Codable {
    let data: Capability
}

struct AIModelsResponse: Codable {
    let models: [AIModelConfig]
}

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
