//
//  Item.swift
//  f1go
//
//  Created by 福井　正剛 on 2026/01/03.
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
