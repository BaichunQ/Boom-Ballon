//
//  Boom_BallonApp.swift
//  Boom Ballon
//
//  Created by Vision Tartanga on 31/3/25.
//

import SwiftUI

@main
struct Boom_BallonApp: App {

    @State private var appModel = AppModel()
    @State private var avPlayerViewModel = AVPlayerViewModel()
    @StateObject var settings = AppSettings()

    // Variables de estado compartidas para la puntuación
    @State private var score: Int = 0
    @State private var timeRemaining: Int = 120
    @State private var record: Int = 0

    var body: some Scene {
        WindowGroup {
            if avPlayerViewModel.isPlaying {
                AVPlayerView(viewModel: avPlayerViewModel)
                    .environmentObject(settings) // Inyectamos en AVPlayerView si lo usa
            } else {
                // Pasamos los bindings a ContentView
                ContentView(score: $score, timeRemaining: $timeRemaining, record: $record)
                    .environment(appModel)
                    .environmentObject(settings)
            }
        }
        .defaultSize(width: 1200, height: 300)
        
        // Para la escena inmersiva "Globos" también pasamos los bindings correspondientes
        ImmersiveSpace(id: "Globos") {
            Globos(score: $score, timeRemaining: $timeRemaining, record: $record)
                .environmentObject(settings)
        }
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environmentObject(settings)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    avPlayerViewModel.play()
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    avPlayerViewModel.reset()
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
