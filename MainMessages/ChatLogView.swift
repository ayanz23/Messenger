//
//  ChatLogView.swift
//  Messenger
//
//  Created by Ayan on 1/4/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import MLKitTranslate

class ChatLogViewModel: ObservableObject {
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    
    @Published var chatMessages = [ChatMessage]()
    
    var chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
            
        fetchMessages()
    }
    
    var firestoreListener: ListenerRegistration?
    
    func fetchUserLanguages(completion: @escaping (TranslateLanguage?, TranslateLanguage?) -> Void) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
              let recipientId = chatUser?.uid else {
            completion(nil, nil)
            return
        }
        
        let group = DispatchGroup()
        var senderLanguage: TranslateLanguage?
        var recipientLanguage: TranslateLanguage?
        
        group.enter()
        FirebaseManager.shared.firestore
            .collection(FirebaseConstants.users)
            .document(currentUserId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Failed to fetch sender's language: \(error)")
                } else if let data = snapshot?.data(),
                          let languageName = data[FirebaseConstants.language] as? String {
                    senderLanguage = self.mapLanguageNameToTranslateLanguage(languageName)
                }
                group.leave()
            }
        
        group.enter()
        FirebaseManager.shared.firestore
            .collection(FirebaseConstants.users)
            .document(recipientId)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Failed to fetch recipient's language: \(error)")
                } else if let data = snapshot?.data(),
                          let languageName = data[FirebaseConstants.language] as? String {
                    recipientLanguage = self.mapLanguageNameToTranslateLanguage(languageName)
                }
                group.leave()
            }
        
        group.notify(queue: .main) {
            completion(senderLanguage, recipientLanguage)
        }
    }
    
    private func mapLanguageNameToTranslateLanguage(_ languageName: String) -> TranslateLanguage? {
        switch languageName.lowercased() {
        case "english":
            return .english
        case "spanish":
            return .spanish
        case "urdu":
            return .urdu
        case "hindi":
            return .hindi
        case "french":
            return .french
        case "arabic":
            return .arabic
        case "russian":
            return .russian
        case "chinese":
            return .chinese
        case "japanese":
            return .japanese
        case "portuguese":
            return .portuguese
        default:
            return nil
        }
    }
    
    func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        firestoreListener?.remove()
        chatMessages.removeAll()
        firestoreListener = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(toId)
            .order(by: FirebaseConstants.timestamp)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for messages: \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({ change in
                    if change.type == .added {
                        do {
                            if let cm = try? change.document.data(as: ChatMessage.self) {
                                self.chatMessages.append(cm)
                                print("Appending chatMessage in ChatLogView: \(Date())")
                            }
                        } catch {
                            print("Failed to decode message: \(error)")
                        }
                    }
                })
                
                DispatchQueue.main.async {
                    self.count += 1
                }
            }
    }
    
    func handleSend() {
            print(chatText)
            guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
            guard let toId = chatUser?.uid else { return }
            
            fetchUserLanguages { [weak self] senderLanguage, recipientLanguage in
                guard let self = self else { return }
                guard let senderLanguage = senderLanguage, let recipientLanguage = recipientLanguage else {
                    self.errorMessage = "Failed to fetch user languages."
                    return
                }
                
                self.translateText(self.chatText, from: senderLanguage, to: recipientLanguage) { translatedText in
                    let recipientMessageText = translatedText ?? self.chatText
                    
                    let senderMessage = ChatMessage(id: nil, fromId: fromId, toId: toId, text: self.chatText, timestamp: Date())
                    let recipientMessage = ChatMessage(id: nil, fromId: fromId, toId: toId, text: recipientMessageText, timestamp: Date())
                    
                    let senderDoc = FirebaseManager.shared.firestore.collection(FirebaseConstants.messages)
                        .document(fromId)
                        .collection(toId)
                        .document()
                    
                    try? senderDoc.setData(from: senderMessage) { error in
                        if let error = error {
                            print(error)
                            self.errorMessage = "Failed to save sender message: \(error)"
                            return
                        }
                        print("Sender message saved successfully")
                        self.persistRecentMessage()
                        self.chatText = ""
                        self.count += 1
                    }
                    
                    let recipientDoc = FirebaseManager.shared.firestore.collection(FirebaseConstants.messages)
                        .document(toId)
                        .collection(fromId)
                        .document()
                    
                    try? recipientDoc.setData(from: recipientMessage) { error in
                        if let error = error {
                            print(error)
                            self.errorMessage = "Failed to save recipient message: \(error)"
                            return
                        }
                        print("Recipient message saved successfully")
                    }
                }
            }
        }
    
    func translateText(_ text: String, from: TranslateLanguage, to: TranslateLanguage, completion: @escaping (String?) -> Void) {
            let options = TranslatorOptions(sourceLanguage: from, targetLanguage: to)
            let translator = Translator.translator(options: options)
            
            translator.downloadModelIfNeeded { error in
                if let error = error {
                    print("Failed to download translation model: \(error)")
                    completion(nil)
                    return
                }
                
                translator.translate(text) { translatedText, error in
                    if let error = error {
                        print("Failed to translate text: \(error)")
                        completion(nil)
                        return
                    }
                    completion(translatedText)
                }
            }
        }
    
    private func persistRecentMessage() {
        guard let chatUser = chatUser else { return }
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = self.chatUser?.uid else { return }
        guard let currentUser = FirebaseManager.shared.currentUser else { return }

        // Create a local copy of chatText to avoid issues with closures
        let originalChatText = self.chatText

        fetchUserLanguages { [weak self] senderLanguage, recipientLanguage in
            guard let self = self else { return }
            guard let senderLanguage = senderLanguage, let recipientLanguage = recipientLanguage else {
                self.errorMessage = "Failed to fetch user languages."
                return
            }

            // Translate the text for the recipient
            self.translateText(originalChatText, from: senderLanguage, to: recipientLanguage) { translatedText in
                let recipientMessageText = translatedText ?? originalChatText

                // Data for the current user's recent message (Original Text)
                let senderRecentMessageDictionary = [
                    FirebaseConstants.timestamp: Timestamp(),
                    FirebaseConstants.text: originalChatText, // Original text
                    FirebaseConstants.fromId: uid,
                    FirebaseConstants.toId: toId,
                    FirebaseConstants.profileImageUrl: chatUser.profileImageUrl,
                    FirebaseConstants.email: chatUser.email
                ] as [String: Any]

                // Save sender's recent message
                let senderDocument = FirebaseManager.shared.firestore
                    .collection(FirebaseConstants.recentMessages)
                    .document(uid)
                    .collection(FirebaseConstants.messages)
                    .document(toId)
                
                senderDocument.setData(senderRecentMessageDictionary) { error in
                    if let error = error {
                        self.errorMessage = "Failed to save sender recent message: \(error)"
                        print("Failed to save sender recent message: \(error)")
                        return
                    }
                }

                // Data for the recipient's recent message (Translated Text)
                let recipientRecentMessageDictionary = [
                    FirebaseConstants.timestamp: Timestamp(),
                    FirebaseConstants.text: recipientMessageText, // Translated text
                    FirebaseConstants.fromId: uid, // Sender's ID
                    FirebaseConstants.toId: toId, // Recipient's ID
                    FirebaseConstants.profileImageUrl: currentUser.profileImageUrl,
                    FirebaseConstants.email: currentUser.email
                ] as [String: Any]

                // Save recipient's recent message
                let recipientDocument = FirebaseManager.shared.firestore
                    .collection(FirebaseConstants.recentMessages)
                    .document(toId)
                    .collection(FirebaseConstants.messages)
                    .document(uid)

                recipientDocument.setData(recipientRecentMessageDictionary) { error in
                    if let error = error {
                        self.errorMessage = "Failed to save recipient recent message: \(error)"
                        print("Failed to save recipient recent message: \(error)")
                        return
                    }
                }
            }
        }
    }
    
    @Published var count = 0
}

struct ChatLogView: View {
    
    @ObservedObject var vm: ChatLogViewModel
    
    var body: some View {
        ZStack {
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(vm.chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            vm.firestoreListener?.remove()
        }
    }
    
    static let emptyScrollToString = "Empty"
    
    private var messagesView: some View {
        VStack {
            if #available(iOS 15.0, *) {
                ScrollView {
                    ScrollViewReader { scrollViewProxy in
                        VStack {
                            ForEach(vm.chatMessages) { message in
                                MessageView(message: message)
                            }
                            
                            HStack{ Spacer() }
                            .id(Self.emptyScrollToString)
                        }
                        .onReceive(vm.$count) { _ in
                            withAnimation(.easeOut(duration: 0.5)) {
                                scrollViewProxy.scrollTo(Self.emptyScrollToString, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(.init(white: 0.95, alpha: 1)))
                .safeAreaInset(edge: .bottom) {
                    chatBottomBar
                        .background(Color(.systemBackground).ignoresSafeArea())
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    private var chatBottomBar: some View {
        HStack(spacing: 16) {
//            Image(systemName: "photo.on.rectangle")
//                .font(.system(size: 24))
//                .foregroundColor(Color(.darkGray))
            ZStack {
                DescriptionPlaceholder()
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.red)
            .cornerRadius(4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct MessageView: View {
    
    let message: ChatMessage
    
    var body: some View {
        VStack {
            if message.fromId == FirebaseManager.shared.auth.currentUser?.uid {
                HStack {
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.red)
                    .cornerRadius(8)
                }
            } else {
                HStack {
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

private struct DescriptionPlaceholder: View {
    var body: some View {
        HStack {
            Text("Description")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
            Spacer()
        }
    }
}

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
        MainMessagesView()
    }
}
