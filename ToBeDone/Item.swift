//
//  Item.swift
//  ToBeDone
//
//  Created by Marius Soarece on 08.03.2025.
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
