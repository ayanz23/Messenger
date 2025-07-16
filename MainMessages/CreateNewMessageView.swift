import SwiftUI
import SDWebImageSwiftUI

class CreateNewMessageViewModel: ObservableObject {
    @Published var foundUser: ChatUser?
    @Published var isLoading = false
    
    func searchUser(byEmail email: String, completion: @escaping (String) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else {
            completion("Please enter a valid email address.")
            return
        }
        
        self.isLoading = true
        self.foundUser = nil
        
        FirebaseManager.shared.firestore.collection("users")
            .whereField("email", isEqualTo: trimmedEmail.lowercased())
            .getDocuments { [weak self] documentsSnapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    if let error = error {
                        completion("Error: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let document = documentsSnapshot?.documents.first else {
                        completion("No user found with this email. Try again.")
                        return
                    }
                    
                    do {
                        let user = try document.data(as: ChatUser.self)
                        if user.uid != FirebaseManager.shared.auth.currentUser?.uid {
                            self.foundUser = user
                            completion("User found! You can start a chat.")
                        } else {
                            completion("Cannot start chat with yourself.")
                        }
                    } catch {
                        completion("Error loading user data. Please try again.")
                    }
                }
            }
    }
}

struct CreateNewMessageView: View {
    let didSelectNewUser: (ChatUser) -> ()
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var vm = CreateNewMessageViewModel()
    
    @State private var emailInput = ""
    @State private var statusMessage = ""
    @State private var showStatus = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Enter user's email", text: $emailInput)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .disabled(vm.isLoading)
                
                Button(action: {
                    showStatus = true
                    vm.searchUser(byEmail: emailInput) { message in
                        statusMessage = message
                    }
                }) {
                    HStack {
                        if vm.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Search")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(vm.isLoading)
                
                if showStatus {
                    Text(statusMessage)
                        .foregroundColor(vm.foundUser == nil ? .red : .green)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if let user = vm.foundUser {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        didSelectNewUser(user)
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: user.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipped()
                                .cornerRadius(50)
                                .overlay(RoundedRectangle(cornerRadius: 50)
                                            .stroke(Color(.label), lineWidth: 2)
                                )
                            Text(user.email)
                                .foregroundColor(Color(.label))
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
