//
//  Avion.swift
//  Boom Ballon
//
//  Created by Vision Tartanga on 30/4/25.
//

import RealityKit
import _RealityKit_SwiftUI
import Foundation

let rightAngleDegrees: Float = 90
let leftAngleDegrees: Float = 270
var rightAngleRadians = rightAngleDegrees * .pi / 180
var leftAngleRadians = leftAngleDegrees * .pi / 180

// Transformación de inicio: posición a la derecha
let rightTransform = Transform(
    scale: SIMD3<Float>(0.03, 0.03, 0.03),
    rotation: simd_quatf(angle: rightAngleRadians, axis: SIMD3<Float>(0, 1, 0)),
    translation: SIMD3<Float>(3, 2, -3)
)

// Transformación destino: posición a la izquierda
let leftTransform = Transform(
    scale: SIMD3<Float>(0.03, 0.03, 0.03),
    rotation: simd_quatf(angle: leftAngleRadians, axis: SIMD3<Float>(0, 1, 0)),
    translation: SIMD3<Float>(-3, 2, -3)
)

struct AvionLoader {
    
    /// Carga el modelo "Avion" y lo configura
    static func loadAvion() async throws -> Entity {
        // Se asume que tienes "Avion.usdz" en tus assets.
        let avion = try await ModelEntity.load(named: "Avion")
        avion.name = "Avion"
        await avion.generateCollisionShapes(recursive: true)
        
        // Configuración inicial: coloca el avión en la posición de inicio (rightTransform)
        avion.transform = rightTransform
        
        return avion
    }
    
    /// Genera de forma continua aviones. Entre cada generación se espera un tiempo aleatorio (entre 4 y 10 segundos).
    static func continuouslySpawnAvions(to content: RealityViewContent) async {
        // Bucle infinito para generar aviones continuamente
        while true {
            // Tiempo de espera aleatorio entre 4 y 10 segundos (en nanosegundos)
            let randomDelay = UInt64.random(in: 4_000_000_000...10_000_000_000)
            try? await Task.sleep(nanoseconds: randomDelay)
            
            do {
                // Crea y añade el avión
                let avion = try await loadAvion()
                content.add(avion)
                // Anima el avión (se moverá de derecha a izquierda y se eliminará al finalizar)
                await animateAvion(avion)
            } catch {
                print("Error al cargar el avión: \(error.localizedDescription)")
            }
        }
    }
    
    /// Anima el avión para que se mueva en línea recta (de derecha a izquierda) y, tras completar la animación, lo elimina.
    static func animateAvion(_ avion: Entity) async {
        let duration: TimeInterval = 2.0 // Duración de la animación
        do {
            // Mueve el avión de su posición inicial (rightTransform) hasta la posición izquierda (leftTransform)
            try await avion.move(
                to: leftTransform,
                relativeTo: nil,
                duration: duration
            )
            // Espera 2 segundos tras finalizar la animación antes de eliminarlo
            try await Task.sleep(nanoseconds: 2_000_000_000)
        } catch {
            print("Error en la animación del avión: \(error)")
        }
        // Elimina el avión de la escena
        await avion.removeFromParent()
    }
    
    /// Una función de conveniencia para agregar un avión sin animarlo.
    static func addAvion(to content: RealityViewContent) async {
        do {
            let avion = try await loadAvion()
            content.add(avion)
        } catch {
            print("Error al cargar el modelo Avion: \(error.localizedDescription)")
        }
    }
}
