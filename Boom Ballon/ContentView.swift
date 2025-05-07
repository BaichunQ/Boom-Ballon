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
    @State var countdown :String = "Restart"
    @State private var isCounting: Bool = false
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
                                timeRemaining = 0
                                await showCountdown()
                                // Reinicio: se establece el tiempo nuevamente (por ejemplo, 120 segundos)
                                timeRemaining = 120
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
                   
                   Text("Tiempo: \(timeString(time: timeRemaining))")
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

}
    
func timeString(time: Int) -> String {
    let minutes = time / 60
    let seconds = time % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

