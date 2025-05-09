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
    @EnvironmentObject var gameManager: GameManager

    @State private var showToggleButton: Bool = false
    
    // Variables de puntuación
    @Binding var score: Int
    //@Binding var gameManager.timeRemaining: Int
    @Binding var record: Int
    @State private var buttonclicked: Bool = false
    @State var countdown :String = "Restart"
    @State private var isCounting: Bool = false
    @State private var creatingBallons: Bool = false
    
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
                HStack(spacing: 20) {
                    Button(action: {
                        // Solo iniciamos la cuenta si no se está contando ya
                        if !isCounting {
                            Task {
                                isCounting = true
                                gameManager.timeRemaining = 0
                                await restartGame()
                                // Reinicio: se establece el tiempo nuevamente (por ejemplo, 120 segundos)
                                isCounting = false
                            }
                        }
                    }) {
                        Text(countdown)
                            .font(.system(size: 50, weight: .bold))
                            .padding()
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    // El botón se deshabilita mientras se cuenta
                    .disabled(isCounting)

                    Button(action: {
                        // Acción para el botón 2
                        print("Botón 2 presionado")
                    }) {
                        Text("Botón 2")
                            .font(.system(size: 50, weight: .bold))
                            .padding()
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Acción para el botón 3
                        print("Botón 3 presionado")
                    }) {
                        Text("Botón 3")
                            .font(.system(size: 50, weight: .bold))
                            .padding()
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 20)
                HStack {
                   Text("Globos: \(score)")
                       .font(.system(size: 50))
                       .padding(16)
                       .background(.ultraThinMaterial)
                       .clipShape(Capsule())
                   
                   Spacer()
                   
                   Text("Tiempo: \(timeString(time: gameManager.timeRemaining))")
                       .font(.system(size: 50))
                       .padding(16)
                       .background(.ultraThinMaterial)
                       .clipShape(Capsule())
                   
                   Spacer()
                   
                   Text("Puntos Récord: \(record)")
                       .font(.system(size: 50))
                       .padding(16)
                       .background(.ultraThinMaterial)
                       .clipShape(Capsule())
                    }
                   .padding()
                   .onAppear {
                               startCountdown()  // Inicia la cuenta atrás de la partida
                           }
               }
            }
    }
    func startCountdown() {
        // Activamos la generación de globos.
        creatingBallons = true
        Task {
            while gameManager.timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    // Resta 1 siempre que timeRemaining sea mayor que cero.
                    if gameManager.timeRemaining > 0 {
                        gameManager.timeRemaining -= 1
                    }
                }
            }
            // Cuando el tiempo llega a 0, se detiene la generación y se actualiza el puntaje.
            await MainActor.run {
                creatingBallons = false
                AvionLoader.changeSpawnAviones(false)
                if score > record {
                    record = score
                }
                score = 0
            }
        }
    }
    func showCountdown() async{
        countdown = "3"
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        countdown = "2"
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        countdown = "1"
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        countdown = "Restart"
    }
    func restartGame() async {
        // Muestra la cuenta atrás en el botón (3-2-1).
        await showCountdown()
        
        // Restablece el estado del juego en el hilo principal.
        Task {
            await gameManager.restartGame()
        }

    }
        
}
    
func timeString(time: Int) -> String {
    let minutes = time / 60
    let seconds = time % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

