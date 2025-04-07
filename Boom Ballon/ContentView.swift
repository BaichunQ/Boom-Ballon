//
//  ContentView.swift
//  Boom Ballon
//
//  Created by Vision Tartanga on 31/3/25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
   
    var body: some View {
        VStack {
            ToggleImmersiveSpaceButton()
            Button(action: {
                Task {
                    await openImmersiveSpace(id: "Globos")
                }
            }){
                Text("Open Scene")
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
