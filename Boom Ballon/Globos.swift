import SwiftUI
import RealityKit
import RealityKitContent
import UIKit

struct BalloonTypeComponent: Component {
    var type: String
}


func propagateBalloonTypeComponent(_ component: BalloonTypeComponent, to entity: Entity) {
    entity.components.set(component)
    for child in entity.children {
        propagateBalloonTypeComponent(component, to: child)
    }
}


func findBalloonEntity(from entity: Entity) -> Entity? {
    if entity.components.has(BalloonTypeComponent.self) {
        return entity
    }
    for child in entity.children {
        if let found = findBalloonEntity(from: child) {
            return found
        }
    }
    return nil
}

struct Globos: View {
    @State private var record: Int = 0
    
    @State private var currentContent: RealityViewContent? = nil
    
    @State private var canonEntity: Entity? = nil
    
    @State private var score: Int = 0
    
    @State private var timeRemaining: Int = 120

    var body: some View {
        ZStack(alignment: .top) {
            RealityView { content in
                let contentCopy = content
                if currentContent == nil {
                    currentContent = contentCopy
                    Task {
                        await loadCanon(in: contentCopy)
                        await createBatchOfThreeBalloons(fromCanon: canonEntity, in: contentCopy)
                        while true {
                            try? await Task.sleep(nanoseconds: 3_000_000_000) // 0.5 segundos
                            await createBatchOfThreeBalloons(fromCanon: canonEntity, in: contentCopy)
                        }
                    }
                    
                    Task {
                        while true {
                            let delay = UInt64.random(in: 5_000_000_000...15_000_000_000)
                            try? await Task.sleep(nanoseconds: delay)
                            if let canon = canonEntity, let content = currentContent {
                                await createYellowBalloon(fromCanon: canon, in: content)
                            }
                        }
                    }
                    Task {
                        while true {
                            let delay = UInt64.random(in: 5_000_000_000...15_000_000_000)
                            try? await Task.sleep(nanoseconds: delay)
                            if let canon = canonEntity, let content = currentContent {
                                await createBoomBalloon(fromCanon: canon, in: content)
                            }
                        }
                    }
                }
            }
            .gesture(tapGesture)
            
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
                    Text("Puntuación Récord: \(record)")
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
    
    
    var tapGesture: some Gesture {
        SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { tap in
                    let tappedEntity = tap.entity
                    
                    // Si el globo tiene el componente de invulnerabilidad, ignoramos el tap
                    if tappedEntity.components.has(InvulnerabilityComponent.self) {
                        print("Entidad invulnerable, se ignora el tap.")
                        return
                    }
                    
                    let explosionPosition = tappedEntity.position(relativeTo: nil)


                    
                    // Reproduce el efecto de explosión
                    if let content = currentContent {
                        Task {
                            await playExplosionEffect(at: explosionPosition, in: content)
                        }
                    }
                    
                    tappedEntity.removeFromParent()
                    
                    // Actualiza el puntaje en función del tipo de globo
                    if let balloonType = tappedEntity.components[BalloonTypeComponent.self] {
                        if balloonType.type == "amarillo" {
                            score += 3
                        } else if balloonType.type == "bomba" {
                            score -= 10
                        } else if balloonType.type == "rojo" {
                            score += 1
                        } else {
                            print("Desconoce el color del globo")
                        }
                    } else {
                        print("El globo no tiene un tipo definido")
                    }
                }
        }

    
    
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
    
    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    
    func loadCanon(in content: RealityViewContent) async {
        if let canon = try? await Entity(named: "CANON") {
            canon.name = "Canon"
            canon.generateCollisionShapes(recursive: true)
            let collisionComponent = CollisionComponent(shapes: [ShapeResource.generateBox(size: [1, 1, 1])])
            canon.components.set(collisionComponent) // Configura colisión
            let canonTransform = Transform(
                scale: [2, 2, 2],
                rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                translation: [0, 0, -3]
            )
            canon.move(to: canonTransform, relativeTo: nil)
            content.add(canon)
            canonEntity = canon
        }
    }
    
    // Componente personalizado para la invulnerabilidad
    struct InvulnerabilityComponent: Component {
        var isInvulnerable: Bool = true
    }
    
    func createBatchOfThreeBalloons(fromCanon canon: Entity?, in content: RealityViewContent) async {
        guard let canon = canon else { return }
        for _ in 0..<3 {
            await createOneBalloon(fromCanon: canon, in: content)
        }
    }
    
    func createOneBalloon(fromCanon canon: Entity, in content: RealityViewContent) async {
        if let balloon = try? await Entity(named: "GloboRojo") {
            balloon.name = "GloboRojo_\(UUID().uuidString)"
            balloon.generateCollisionShapes(recursive: true)
            balloon.components.set(InputTargetComponent())
            balloon.components.set(PhysicsBodyComponent(massProperties: .default,
                                                         material: nil,
                                                         mode: .kinematic))
            // Asigna y propaga el componente que identifica el tipo "rojo".
            let typeComponent = BalloonTypeComponent(type: "rojo")
            propagateBalloonTypeComponent(typeComponent, to: balloon)
            
            // Asigna invulnerabilidad temporal al globo
            balloon.components.set(InvulnerabilityComponent(isInvulnerable: true))
            
            // Después de 1 segundo, remueve la invulnerabilidad para permitir la interacción
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                balloon.components.remove(InvulnerabilityComponent.self)
            }
            
            let canonPosition = canon.position(relativeTo: nil)
            let spawnYOffset: Float = 0.5
            let spawnZOffset: Float = -0.1
            let balloonTransform = Transform(
                scale: [1, 1, 1],
                rotation: canon.orientation(relativeTo: nil),
                translation: [canonPosition.x, canonPosition.y + spawnYOffset, canonPosition.z + spawnZOffset]
            )
            balloon.move(to: balloonTransform, relativeTo: nil)
            content.add(balloon)
            
            Task { await animateBalloon(entity: balloon) }
            scheduleBalloonRemoval(entity: balloon, after: 3)
        }
    }
    
    // Crear un globo amarillo.
    func createYellowBalloon(fromCanon canon: Entity, in content: RealityViewContent) async {
        if let balloon = try? await Entity(named: "GloboAmarillo") {
            balloon.name = "GloboAmarillo_\(UUID().uuidString)"
            balloon.generateCollisionShapes(recursive: true)
            balloon.components.set(InputTargetComponent())
            balloon.components.set(PhysicsBodyComponent(massProperties: .default,
                                                         material: nil,
                                                         mode: .kinematic))
            
            let typeComponent = BalloonTypeComponent(type: "amarillo")
            propagateBalloonTypeComponent(typeComponent, to: balloon)
            
            let canonPosition = canon.position(relativeTo: nil)
            let spawnYOffset: Float = 0.5
            let spawnZOffset: Float = -0.1
            let balloonTransform = Transform(
                scale: [1, 1, 1],
                rotation: canon.orientation(relativeTo: nil),
                translation: [canonPosition.x, canonPosition.y + spawnYOffset, canonPosition.z + spawnZOffset]
            )
            balloon.move(to: balloonTransform, relativeTo: nil)
            content.add(balloon)
            
            // Animación para globo amarillo (más rápido) y eliminación a los 3 segundos.
            Task { await animateSpecialBalloon(entity: balloon) }
            scheduleBalloonRemoval(entity: balloon, after: 3)
        }
    }
    
    func createBoomBalloon(fromCanon canon: Entity, in content: RealityViewContent) async {
        if let balloon = try? await Entity(named: "Bomba") {
            balloon.name = "Bomba_\(UUID().uuidString)"
            balloon.generateCollisionShapes(recursive: true)
            balloon.components.set(InputTargetComponent())
            balloon.components.set(PhysicsBodyComponent(massProperties: .default,
                                                         material: nil,
                                                         mode: .kinematic))
            
            let typeComponent = BalloonTypeComponent(type: "bomba")
            propagateBalloonTypeComponent(typeComponent, to: balloon)
            
            let canonPosition = canon.position(relativeTo: nil)
            let spawnYOffset: Float = 0.5
            let spawnZOffset: Float = -0.1
            let balloonTransform = Transform(
                scale: [1, 1, 1],
                rotation: canon.orientation(relativeTo: nil),
                translation: [canonPosition.x, canonPosition.y + spawnYOffset, canonPosition.z + spawnZOffset]
            )
            balloon.move(to: balloonTransform, relativeTo: nil)
            content.add(balloon)
            
            
            Task { await animateSpecialBalloon(entity: balloon) }
            scheduleBalloonRemoval(entity: balloon, after: 3)
        }
    }
    
    
    func animateBalloon(entity: Entity) async {
        while true {
            let duration = TimeInterval.random(in: 2...4)
            let moveUp = Transform(
                scale: [1, 1, 1],
                rotation: simd_quatf(
                    angle: Float.random(in: -0.3...0.3),
                    axis: [Float.random(in: -0.2...0.2), 1, Float.random(in: -0.2...0.2)]
                ),
                translation: [
                        Float.random(in: -0.3...0.3),
                        2.5,
                        Float.random(in: -0.05...0.05)
                ]
            )
            entity.move(to: moveUp, relativeTo: canonEntity, duration: duration, timingFunction: .easeInOut)
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }
    }



    
    
    func animateSpecialBalloon(entity: Entity) async {
        while true {
            var duration = TimeInterval.random(in: 2...3)
            if entity.name == "Bomba"{
                duration = 5
            }
            
            let moveUp = Transform(
                scale: [1, 1, 1],
                rotation: simd_quatf(
                    angle: Float.random(in: -0.3...0.3),
                    axis: [Float.random(in: -0.2...0.2), 1, Float.random(in: -0.2...0.2)]
                ),
                translation: [
                    Float.random(in: -0.3...0.3),
                    2.5,
                    Float.random(in: -0.05...0.05)
                ]
            )
            entity.move(to: moveUp, relativeTo: canonEntity, duration: duration, timingFunction: .easeInOut)
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }
    }
    
    
    func scheduleBalloonRemoval(entity: Entity, after seconds: TimeInterval = 3) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            entity.removeFromParent()
        }
    }
}

func playExplosionEffect(at position: SIMD3<Float>, in content: RealityViewContent) async {
    
    if let particleEntity = try? await Entity.load(named: "Particulas") {
        particleEntity.name = "Particulas" // (Opcional)
        
        particleEntity.transform.translation = position
        content.add(particleEntity)
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            particleEntity.removeFromParent()
        }
    }
}
