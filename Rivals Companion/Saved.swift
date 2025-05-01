//
//  Item.swift
//  Rivals Companion
//
//  Created by Ryan Sun on 4/23/25.
//

import Foundation
import SwiftData

@Model
final class Saved {
    var name: String
    var timestamp: Date

    init(name: String, timestamp: Date = .now) {
        self.name = name
        self.timestamp = timestamp
    }
}
