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
    @EnvironmentObject var settings: AppSettings
    @State private var showToggleButton: Bool = false
    
    // Variables de puntuación
    @Binding var score: Int
    @Binding var timeRemaining: Int
    @Binding var record: Int
    @State private var buttonclicked: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            if buttonclicked == false{
                Button(action: {
                    Task {
                        showToggleButton = true
                        buttonclicked = true
                        await openImmersiveSpace(id: "Globos")
                    }
                }) {
                    Text("Empezar")
                }
            }
            
            if showToggleButton {
                HStack {
                   Text("Globos: \(score)")
                       .font(.system(size: 50, weight: .bold))
                       .padding(16)
                       .background(.ultraThinMaterial)
                       .clipShape(Capsule())
                   
                   Spacer()
                   
                   Text("Tiempo: \(timeString(time: timeRemaining))")
                       .font(.system(size: 50, weight: .bold))
                       .padding(16)
                       .background(.ultraThinMaterial)
                       .clipShape(Capsule())
                   
                   Spacer()
                   
                   Text("Puntos Récord: \(record)")
                       .font(.system(size: 50, weight: .bold))
                       .padding(16)
                       .background(.ultraThinMaterial)
                       .clipShape(Capsule())
                    }
                   .padding()
               }
            }
    }
}
    
    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
