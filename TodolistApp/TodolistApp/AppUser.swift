//
//  AppUser.swift
//  TodolistApp
//

import Foundation

struct AppUser: Identifiable, Codable {
    let id: String
    let fullName: String
    let email: String

    var initials: String {
        let parts = fullName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }
}
