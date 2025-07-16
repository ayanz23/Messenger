//
//  SplashScreenView.swift
//  Messenger
//
//  Created by Ayan on 1/9/25.
//

import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.red
                .ignoresSafeArea()
            Text("Messenger")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
    }
}
