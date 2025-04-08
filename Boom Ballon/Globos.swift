import SwiftUI
import RealityKit
import RealityKitContent
import UIKit

struct BombStatusComponent: Component {
    var exploded: Bool = false
}
extension Entity {
    /// Aplica el componente a la entidad y a todos sus hijos de forma recursiva
    func propagate<T: Component>(component: T) {
        self.components.set(component)
        for child in self.children {
            child.propagate(component: component)
        }
    }
}
extension Entity {
    /// Busca recursivamente hacia arriba (en la jerarquía) una entidad que tenga un componente BalloonTypeComponent.
   
}

struct BalloonTypeComponent: Component {
    var type: String
}

struct Globos: View {
    
    // Define el componente para indicar el tipo de globo (rojo, amarillo, bomba)
   
    
    
    
    // Define el componente para marcar la invulnerabilidad temporal del globo
    struct InvulnerabilityComponent: Component {
        var isInvulnerable: Bool = true
    }
    @State private var record: Int = 0
    @State private var score: Int = 0
    @State private var timeRemaining: Int = 120
    @State private var currentContent: RealityViewContent? = nil
    
    // Arreglo para almacenar los cañones
    @State private var cannonEntities: [Entity] = []
    
    var body: some View {
        ZStack(alignment: .top) {
            RealityView { content in
                let contentCopy = content  // Hacemos copia de 'content'
                if currentContent == nil {
                    currentContent = contentCopy
                    Task {
                        await loadCannons(in: contentCopy)
                        await startGeneratingBalloons(in: contentCopy)
                    }
                }
            }
            .gesture(tapGesture)
            
            // Interfaz de usuario para puntaje, tiempo y récord
            VStack {
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
                Spacer()
            }
        }
        .onAppear { startCountdown() }
    }
    
    // MARK: - Cañones
    
    func loadCannons(in content: RealityViewContent) async {
        let numCannons = 3
        let cannonSpacing: Float = 1.5  // Ajusta el espaciado
        cannonEntities.removeAll()
        // Calcula el offset inicial para que queden centrados horizontalmente
        let startX = -cannonSpacing * Float(numCannons - 1) / 2.0
        
        for i in 0..<numCannons {
            if let canon = try? await Entity(named: "CANON") {
                canon.name = "Canon_\(i)"
                canon.generateCollisionShapes(recursive: true)
                let collisionComponent = CollisionComponent(shapes: [ShapeResource.generateBox(size: [1, 1, 1])])
                canon.components.set(collisionComponent)
                
                let xOffset = startX + Float(i) * cannonSpacing
                let canonTransform = Transform(
                    scale: SIMD3<Float>(2, 2, 2),
                    rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                    translation: SIMD3<Float>(xOffset, 0, -3)
                )
                canon.move(to: canonTransform, relativeTo: nil)
                content.add(canon)
                cannonEntities.append(canon)
            }
        }
    }
    
    // MARK: - Generación Independiente de Globos
    
    func startGeneratingBalloons(in content: RealityViewContent) async {
        // Para cada cañón, se lanza una tarea independiente
        for cannon in cannonEntities {
            Task {
                await generateBalloons(for: cannon, in: content)
            }
        }
    }
    
    private func generateBalloons(for cannon: Entity, in content: RealityViewContent) async {
        while true {
            let probability = Int.random(in: 0..<100)
            if probability < 80 {
                // 80% de probabilidad: globo rojo
                await createOneBalloon(from: cannon, in: content)
                // Reducción del delay para aumentar la velocidad general
                let delay = UInt64.random(in: 500_000_000...1_500_000_000)
                try? await Task.sleep(nanoseconds: delay)
            } else if probability < 85 {
                // 5% de probabilidad: globo amarillo (más exclusivo)
                await createYellowBalloon(from: cannon, in: content)
                let delay = UInt64.random(in: 3_000_000_000...4_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            } else {
                // 15% de probabilidad: globo bomba
                await createBoomBalloon(from: cannon, in: content)
                let delay = UInt64.random(in: 3_000_000_000...4_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }
    
    // MARK: - Creación de Globos desde un Cañón
    
    func createOneBalloon(from cannon: Entity, in content: RealityViewContent) async {
        if let balloon = try? await Entity(named: "GloboRojo") {
            balloon.name = "GloboRojo_\(UUID().uuidString)"
            balloon.generateCollisionShapes(recursive: true)
            balloon.components.set(InputTargetComponent())
            balloon.components.set(PhysicsBodyComponent(massProperties: .default,
                                                        material: nil,
                                                        mode: .kinematic))
            let typeComponent = BalloonTypeComponent(type: "rojo")
            balloon.propagate(component: typeComponent)
            
            // Invulnerabilidad temporal para evitar taps inmediatos
            balloon.components.set(InvulnerabilityComponent(isInvulnerable: true))
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if balloon.components.has(InvulnerabilityComponent.self) {
                        balloon.components.remove(InvulnerabilityComponent.self)
                    }
                }
            }
            
            let canonPosition = cannon.position(relativeTo: nil)
            let spawnYOffset: Float = 0.5
            let spawnZOffset: Float = -0.1
            let balloonTransform = Transform(
                scale: SIMD3<Float>(1, 1, 1),
                rotation: cannon.orientation(relativeTo: nil),
                translation: SIMD3<Float>(canonPosition.x, canonPosition.y + spawnYOffset, canonPosition.z + spawnZOffset)
            )
            balloon.move(to: balloonTransform, relativeTo: nil)
            content.add(balloon)
            
            // Lanza la animación del globo referenciando el cañón
            Task {
                await animateBalloon(entity: balloon, relativeTo: cannon)
            }
            scheduleBalloonRemoval(entity: balloon, after: 3)
        }
    }
    
    func createYellowBalloon(from cannon: Entity, in content: RealityViewContent) async {
        if let balloon = try? await Entity(named: "GloboAmarillo") {
            balloon.name = "GloboAmarillo_\(UUID().uuidString)"
            balloon.generateCollisionShapes(recursive: true)
            balloon.components.set(InputTargetComponent())
            balloon.components.set(PhysicsBodyComponent(massProperties: .default,
                                                        material: nil,
                                                        mode: .kinematic))
            let typeComponent = BalloonTypeComponent(type: "amarillo")
            balloon.propagate(component: typeComponent)
            
            balloon.components.set(InvulnerabilityComponent(isInvulnerable: true))
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if balloon.components.has(InvulnerabilityComponent.self) {
                        balloon.components.remove(InvulnerabilityComponent.self)
                    }
                }
            }
            
            let canonPosition = cannon.position(relativeTo: nil)
            let spawnYOffset: Float = 0.5
            let spawnZOffset: Float = -0.1
            let balloonTransform = Transform(
                scale: SIMD3<Float>(1, 1, 1),
                rotation: cannon.orientation(relativeTo: nil),
                translation: SIMD3<Float>(canonPosition.x, canonPosition.y + spawnYOffset, canonPosition.z + spawnZOffset)
            )
            balloon.move(to: balloonTransform, relativeTo: nil)
            content.add(balloon)
            
            Task {
                await animateSpecialBalloon(entity: balloon, relativeTo: cannon)
            }
            scheduleBalloonRemoval(entity: balloon, after: 3)
        }
    }
    
    func createBoomBalloon(from cannon: Entity, in content: RealityViewContent) async {
        if let balloon = try? await Entity(named: "Bomba") {
            balloon.name = "Bomba_\(UUID().uuidString)"
            balloon.generateCollisionShapes(recursive: true)
            balloon.components.set(InputTargetComponent())
            balloon.components.set(PhysicsBodyComponent(massProperties: .default,
                                                         material: nil,
                                                         mode: .kinematic))
            let typeComponent = BalloonTypeComponent(type: "bomba")
            balloon.propagate(component: typeComponent)
            
            // Asigna el componente de estado para bombas (por defecto exploded = false)
            balloon.components.set(BombStatusComponent())
            
            let canonPosition = cannon.position(relativeTo: nil)
            let spawnYOffset: Float = 0.5
            let spawnZOffset: Float = -0.1
            let balloonTransform = Transform(
                scale: SIMD3<Float>(1, 1, 1),
                rotation: cannon.orientation(relativeTo: nil),
                translation: SIMD3<Float>(canonPosition.x, canonPosition.y + spawnYOffset, canonPosition.z + spawnZOffset)
            )
            balloon.move(to: balloonTransform, relativeTo: nil)
            content.add(balloon)
            
            Task {
                await animateSpecialBalloon(entity: balloon, relativeTo: cannon)
            }
            scheduleBalloonRemoval(entity: balloon, after: 3)
        }
    }

    
    // MARK: - Animaciones y Eliminación de Globos (Ejemplos Directos)
    
    // Función para animar globos básicos
    func animateBalloon(entity: Entity, relativeTo reference: Entity?) async {
        while true {
            let duration = TimeInterval.random(in: 2...4)
            let moveUp = Transform(
                scale: SIMD3<Float>(1, 1, 1),
                rotation: simd_quatf(
                    angle: Float.random(in: -0.3...0.3),
                    axis: SIMD3<Float>(Float.random(in: -0.2...0.2),
                                       1,
                                       Float.random(in: -0.2...0.2))
                ),
                translation: SIMD3<Float>(
                    Float.random(in: -0.3...0.3),
                    2.5,
                    Float.random(in: -0.05...0.05)
                )
            )
            entity.move(to: moveUp, relativeTo: reference, duration: duration, timingFunction: .easeInOut)
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            } catch {
                break
            }
        }
    }
    
    // Función para animar globos especiales
    func animateSpecialBalloon(entity: Entity, relativeTo reference: Entity?) async {
        while true {
            var duration = TimeInterval.random(in: 2...3)
            if entity.name.contains("Bomba") {
                duration = 5
            }
            let moveUp = Transform(
                scale: SIMD3<Float>(1, 1, 1),
                rotation: simd_quatf(
                    angle: Float.random(in: -0.3...0.3),
                    axis: SIMD3<Float>(Float.random(in: -0.2...0.2),
                                       1,
                                       Float.random(in: -0.2...0.2))
                ),
                translation: SIMD3<Float>(
                    Float.random(in: -0.3...0.3),
                    2.5,
                    Float.random(in: -0.05...0.05)
                )
            )
            entity.move(to: moveUp, relativeTo: reference, duration: duration, timingFunction: .easeInOut)
            do {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            } catch {
                break
            }
        }
    }
    
    func scheduleBalloonRemoval(entity: Entity, after seconds: TimeInterval = 3) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                if let balloonType = entity.components[BalloonTypeComponent.self],
                   balloonType.type == "bomba",
                   entity.parent != nil {
                    // Se penaliza solo si el componente de estado indica que no fue explotado.
                    if let bombStatus = entity.components[BombStatusComponent.self] as? BombStatusComponent, bombStatus.exploded == false {
                        score -= 10
                    }
                }
                entity.removeFromParent()
            }
        }
    }

    
    // MARK: - Temporizador
    
    func startCountdown() {
        Task {
            while true {
                while timeRemaining > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run { timeRemaining -= 1 }
                }
                await MainActor.run {
                    if score > record { record = score }
                    score = 0
                    timeRemaining = 120
                }
            }
        }
    }
    
    // MARK: - Utilidades
    
    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Gestión de Taps
    
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { tap in
                // Si es necesario, busca el nodo raíz que tenga el BalloonTypeComponent.
                // En este ejemplo usamos el entity directamente.
                let tappedEntity = tap.entity
                let explosionPosition = tappedEntity.position(relativeTo: nil)
                
                if let content = currentContent {
                    Task {
                        await playExplosionEffect(at: explosionPosition, in: content)
                    }
                }
                
                if let balloonType = tappedEntity.components[BalloonTypeComponent.self] {
                    switch balloonType.type {
                    case "amarillo":
                        score += 3
                    case "rojo":
                        score += 1
                    case "bomba":
                        // Marca la bomba como explotada reemplazando el componente
                        tappedEntity.components.set(BombStatusComponent(exploded: true))
                        // No penalizamos al tocarla
                    default:
                        break
                    }
                } else {
                    print("El globo no tiene un tipo definido")
                }
                
                // Elimina la entidad inmediatamente
                tappedEntity.removeFromParent()
            }
    }

    
    func playExplosionEffect(at position: SIMD3<Float>, in content: RealityViewContent) async {
        if let particleEntity = try? await Entity.load(named: "Particulas") {
            particleEntity.name = "Particulas" // opcional, para identificarla
            particleEntity.transform.translation = position
            content.add(particleEntity)
            
            // Espera 2 segundos para que se vea el efecto, luego remueve la entidad.
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                particleEntity.removeFromParent()
            }
        }
    }
}
