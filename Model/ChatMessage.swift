//
//  ChatMessage.swift
//  Messenger
//
//  Created by Ayan on 1/6/25.
//

import Foundation
import FirebaseFirestore

struct ChatMessage: Codable, Identifiable {
    @DocumentID var id: String?
    let fromId, toId, text: String
    let timestamp: Date
}
