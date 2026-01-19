//
//  PHPModels.swift
//  Velo
//
//  Models and Enums for PHP management.
//

import Foundation


/// Represents a PHP extension with its status
struct PHPExtension: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let isLoaded: Bool
    let isCore: Bool
}

