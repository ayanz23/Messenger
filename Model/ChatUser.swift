//
//  ChatUser.swift
//  Messenger
//
//  Created by Ayan on 12/30/24.
//

import FirebaseFirestore

struct ChatUser: Codable, Identifiable {
    @DocumentID var id: String?
    let uid, email, profileImageUrl: String
}
