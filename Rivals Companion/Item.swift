//
//  Item.swift
//  Rivals Companion
//
//  Created by Ryan Sun on 4/23/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
