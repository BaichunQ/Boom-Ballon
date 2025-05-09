//
//  GameManager.swift
//  Boom Ballon
//
//  Created by Vision Tartanga on 8/5/25.
//


import SwiftUI

final class GameManager: ObservableObject {
    static let shared = GameManager()
    
    @Published var timeRemaining: Int = 120
    @Published var score: Int = 0
    @Published var creatingBallons: Bool = false
    
    // Referencia al Task actual
    private var countdownTask: Task<Void, Never>? = nil

    // Método que inicia la cuenta atrás
    func startCountdown() {
        // Cancelamos el task anterior si existe
        countdownTask?.cancel()
        
        // Activamos la generación de globos
        creatingBallons = true
        
        // Creamos y almacenamos el nuevo Task
        countdownTask = Task { @MainActor in
            while self.timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                // Permitir la cancelación y salir del loop si se cancela
                if Task.isCancelled { break }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                }
            }
            // Cuando termine el countdown, desactivar la generación de globos
            self.creatingBallons = false
        }
    }
    
    // Método que reinicia el juego
    func restartGame() async {
        // Cancelamos el task de cuenta atrás anterior
        countdownTask?.cancel()
        
        // En el hilo principal, restablecemos el estado
        await MainActor.run {
            self.timeRemaining = 120
            self.score = 0
            self.creatingBallons = true
        }
        
        // Iniciamos un nuevo countdown sin await para que se maneje asíncronamente
        startCountdown()
    }
}
