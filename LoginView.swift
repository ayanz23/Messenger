//  ContentView.swift
//  Messenger
//
//  Created by Ayan on 12/28/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    let didCompleteLoginProcess: () -> ()
    
    @State private var shouldShowImagePicker = false
    @State private var selectedLanguage = "English"
    @State private var languages = ["English", "Spanish", "French", "Portuguese", "Arabic", "Urdu", "Hindi", "Russian", "Chinese", "Japanese"]
    @State var image: UIImage?
    @State var loginStatusMessage = ""
    @State var isNewUser = false
    @State var isFirstPage = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    
                    if isFirstPage {
                        GoogleSignInButton(action: handleGoogleSignIn)
                                                    .frame(height: 50)
                                                    .padding()
                    } else {
                        
                        // Language Picker
                        Picker("Select Language", selection: $selectedLanguage) {
                            ForEach(languages, id: \.self) { language in
                                Text(language).tag(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        
                        // "Continue" Button for new account creation
                        if isNewUser {
                            Button(action: handleContinueButton) {
                                Text("Continue")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Error Message
                    Text(self.loginStatusMessage)
                        .foregroundColor(.red)
                        .padding(.top, 10)
                }
                .padding()
            }
            .navigationTitle(isFirstPage ? "Log In" : "Create Account")
            .background(Color(.init(white: 0, alpha: 0.05))
                .ignoresSafeArea())
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func handleContinueButton() {
        guard let user = Auth.auth().currentUser else {
            loginStatusMessage = "No user found."
            return
        }
        
        // Store user information (with language preference and profile image if any)
        storeGoogleUserInformation(uid: user.uid)
    }
    
    private func handleGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            self.loginStatusMessage = "Missing Client ID"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            self.loginStatusMessage = "Failed to find the root view controller."
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                self.loginStatusMessage = "Google Sign-In failed: \(error.localizedDescription)"
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.loginStatusMessage = "Failed to fetch user or token."
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self.loginStatusMessage = "Firebase sign-in failed: \(error.localizedDescription)"
                    return
                }
                
                self.checkIfUserExists(authResult?.user.uid ?? "", user: user)
            }
        }
    }
    
    private func checkIfUserExists(_ uid: String, user: GIDGoogleUser) {
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                self.loginStatusMessage = "Failed to check user existence: \(error.localizedDescription)"
                return
            }
            
            if snapshot?.exists == true {
                // User exists, proceed with login
                self.loginStatusMessage = "Welcome back, \(user.profile?.name ?? "User")!"
                self.didCompleteLoginProcess()
            } else {
                // New user, show the account creation flow
                self.isFirstPage = false
                self.isNewUser = true
            }
        }
    }
    
    private func storeGoogleUserInformation(uid: String) {
        let user = Auth.auth().currentUser
        let userData: [String: Any] = [
            "uid": uid,
            "email": user?.email ?? "",
            "name": user?.displayName ?? "",
            "profileImageUrl": user?.photoURL?.absoluteString ?? "",
            "language": selectedLanguage == "English" ? "English" : selectedLanguage // Only save if it's different from default
        ]
        
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).setData(userData) { error in
                if let error = error {
                    self.loginStatusMessage = "Failed to store user info: \(error.localizedDescription)"
                    return
                }
                self.loginStatusMessage = "User information saved successfully."
                self.didCompleteLoginProcess() // Proceed with login after saving user info
            }
    }
}

struct ContentView_Previews1: PreviewProvider {
    static var previews: some View {
        LoginView(didCompleteLoginProcess: {
            // Handle the completion of the login process
        })
    }
}
