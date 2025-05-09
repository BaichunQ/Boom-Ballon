import SwiftUI
import RealityKit
import RealityKitContent
import UIKit
  
//private var gameManager.creatingBallons: Bool = false
private var currentContent: RealityViewContent? = nil
private var showScene: Bool = true
private var cannonEntities: [Entity] = []
private var skyboxEntity: ModelEntity?
private var contentLoaded: Bool = false

struct Globos: View {
    struct InvulnerabilityComponent: Component {
        var isInvulnerable: Bool = true
    }
    @State private var collisionSubscription: EventSubscription?
    @EnvironmentObject var gameManager: GameManager


    @Binding var score: Int
    @Binding var timeRemaining: Int
    @Binding var record: Int
    @EnvironmentObject var settings: AppSettings

    
    var body: some View {
        
            ZStack(alignment: .top) {
                if showScene {
                    RealityView { content in
                        // Guarda la referencia al content si aún no se hizo
                        if collisionSubscription == nil {
                            collisionSubscription = content.subscribe(to: CollisionEvents.Began.self) { event in
                                // Este bloque se ejecuta cada vez que ocurre un evento de colisión.
                                Task { @MainActor in
                                    // Identifica la colisión entre el avión y el globo
                                    let balloonEntity: Entity? = {
                                        if event.entityA.name.contains("Avion") && event.entityB.components.has(BalloonTypeComponent.self) {
                                            return event.entityB
                                        } else if event.entityB.name.contains("Avion") && event.entityA.components.has(BalloonTypeComponent.self) {
                                            return event.entityA
                                        }
                                        return nil
                                    }()
                                    
                                    if let balloon = balloonEntity, balloon.parent != nil {
                                        // Este código se ejecuta en cada colisión válida
                                        print("Colisión detectada: eliminando globo \(balloon.name)")
                                        balloon.removeFromParent()
                                    }
                                }
                            }
                        }

                        if currentContent == nil {
                            let contentCopy = content
                                currentContent = contentCopy
                                Task {
                                    await loadCannons(in: contentCopy)
                                    await startGeneratingBalloons(in: contentCopy)
                                    await AvionLoader.continuouslySpawnAvions(to: contentCopy)
                                }
                        }
                        
                        // Manejo del skybox utilizando la referencia almacenada
                        if settings.isSkyboxActive {
                            // Si no existe aún el skybox, lo creamos y lo agregamos
                            if skyboxEntity == nil, let newSkybox = createSkybox() {
                                newSkybox.name = "skyboxEntity"
                                skyboxEntity = newSkybox
                                content.add(newSkybox)
                            }
                        } else {
                            // Si se desactiva el skybox, lo removemos si existe
                            if let existingSkybox = skyboxEntity {
                                existingSkybox.removeFromParent()
                                skyboxEntity = nil
                            }
                        }
                        // Dentro del closure de RealityView, luego de haber agregado las entidades a la escena:
                           

                    }
                    
                    .gesture(tapGesture)
                }
                /*
                // Interfaz de usuario de puntaje, tiempo, etc.
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
                }*/
            }
           // .onAppear { startCountdown() }
        }
    
    // MARK: - Skybox
    
    private func createSkybox() -> ModelEntity? {
        let sphere = MeshResource.generateSphere(radius: 2)
        var material = UnlitMaterial()
        do {
            let texture = try TextureResource.load(named: "test")
            material.color = .init(texture: .init(texture))
        } catch {
            print("Error al cargar la textura del skybox: \(error.localizedDescription)")
            return nil
        }
        let modelEntity = ModelEntity(mesh: sphere, materials: [material])
        // Escala invertida para que la textura se vea desde el interior
        modelEntity.scale = SIMD3<Float>(-10, 10, 10)
        return modelEntity
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
                gameManager.creatingBallons = true
                await generateBalloons(for: cannon, in: content)
            }
        }
    }
    
    private func generateBalloons(for cannon: Entity, in content: RealityViewContent) async {
        while gameManager.creatingBallons {
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
                //await createBoomBalloon(from: cannon, in: content)
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
            await animateBalloon(entity: balloon, relativeTo: cannon)
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

                await animateBalloon(entity: balloon, relativeTo: cannon)

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

                await animateBalloon(entity: balloon, relativeTo: cannon)

            scheduleBalloonRemoval(entity: balloon, after: 3)
        }
    }
    
    
    // MARK: - Animaciones y Eliminación de Globos (Ejemplos Directos)
    
    // Función para animar globos básicos
    func animateBalloon(entity: Entity, relativeTo reference: Entity?) async {
       
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
    }
    
    // Función para animar globos especiales
    func animateSpecialBalloon(entity: Entity, relativeTo reference: Entity?) async {
       
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
    }
    
    func scheduleBalloonRemoval(entity: Entity, after seconds: TimeInterval) {
        // Capturamos una referencia fuerte a la entidad en el momento de la llamada.
        let strongEntity = entity
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await MainActor.run {
                // Solo eliminamos si la entidad aún está en la jerarquía.
                
                if strongEntity.parent != nil {
                    strongEntity.removeFromParent()
                }
            }
        }
    }


    
    
    
    
    // MARK: - Temporizador
   /*
    func startCountdown() {
        Task {
            // Bucle para decrementar el tiempo hasta cero.
            gameManager.creatingBallons=true
            while timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if(timeRemaining>0){
                        timeRemaining -= 1
                    } else{
                        gameManager.creatingBallons = false
                    }
                }
            }
            
            // Una vez terminado el tiempo, actualiza el récord (si es necesario)
            await MainActor.run {
                gameManager.creatingBallons = false
                AvionLoader.changeSpawnAviones(false)
                if score > record {
                    record = score
                }
                score = 0
            }
            
        }
    }
    /// Función para reiniciar el juego: muestra la cuenta, reinicia valores y reactiva el countdown.
    func restartGame() async {
        // Luego, en el hilo principal, reinicia las variables del juego.
        await MainActor.run {
            timeRemaining = 120   // Restablece el tiempo a 120 segundos.
            score = 0             // Reinicia la puntuación.
            gameManager.creatingBallons = true // Reactiva la generación de globos.
            // Si manejas otros spawns (por ejemplo, aviones), reactívalos aquí.
        }
        
        // Lanza de nuevo el countdown sin await para que se maneje de forma asíncrona.
        startCountdown()
    }
*/
    
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
                let tappedEntity = tap.entity
                
                // Obtenemos el componente que indica el tipo del globo
                guard let balloonType = tappedEntity.components[BalloonTypeComponent.self] else {
                    print("El globo no tiene un tipo definido")
                    tappedEntity.removeFromParent()
                    return
                }
                
                // Actualizamos el puntaje según el tipo de globo
                switch balloonType.type {
                case "amarillo":
                    score += 3
                case "rojo":
                    score += 1
                case "bomba":
                    score = max(0, score - 10)
                default:
                    break
                }
                
                // Obtenemos la posición actual del globo
                let position = tappedEntity.position(relativeTo: nil)
                if let content = currentContent {
                    Task {
                        if balloonType.type == "bomba" {
                            await playBombExplosionEffect(at: position, in: content)
                        } else if balloonType.type == "amarillo" {
                            // Para globos amarillos, cargamos el efecto "Brillos"
                            await playBrillosEffect(at: position, in: content)
                        } else {
                            // Si es de otro tipo, usamos el efecto por defecto
                            await playExplosionEffect(at: position, in: content)
                        }
                    }
                }
                
                // Eliminamos el globo de la escena
                tappedEntity.removeFromParent()
            }
    }
    
    func playExplosionEffect(at position: SIMD3<Float>, in content: RealityViewContent) async {
        if let particleEntity = try? await Entity.load(named: "Particulas") {
            particleEntity.name = "Particulas" // opcional, para identificarla
            particleEntity.transform.translation = position
            content.add(particleEntity)
            
            // Espera 500 milisegundos para que se vea el efecto y luego lo elimina.
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                particleEntity.removeFromParent()
            }
        }
    }
    
    func playBombExplosionEffect(at position: SIMD3<Float>, in content: RealityViewContent) async {
        if let explosionEntity = try? await Entity.load(named: "Explosion") {
            print("Explosion cargada correctamente.")  // Depuración
            explosionEntity.name = "Explosion"
            explosionEntity.transform.translation = position
            content.add(explosionEntity)
            
            if let animation = explosionEntity.availableAnimations.first {
                explosionEntity.playAnimation(animation, transitionDuration: 0, startsPaused: false)
                // Asumimos a modo de ejemplo que la animación dura 1 segundo
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } else {
                // Si no tiene animación, lo mostramos por 300ms
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            
            await MainActor.run {
                explosionEntity.removeFromParent()
            }
        } else {
            print("No se pudo cargar el modelo 'Explosion'")
        }
    }
    
    func playBrillosEffect(at position: SIMD3<Float>, in content: RealityViewContent) async {
        if let brillosEntity = try? await Entity.load(named: "Brillos") {
            brillosEntity.name = "Brillos"
            // Posicionar el efecto en el punto del touch.
            brillosEntity.transform.translation = position
            content.add(brillosEntity)
            
            // Si el modelo tiene alguna animación, se reproduce de inmediato
            if let animation = brillosEntity.availableAnimations.first {
                brillosEntity.playAnimation(animation, transitionDuration: 0, startsPaused: false)
                // Asumimos que la animación dura, por ejemplo, 0.8 segundos (800 millones de nanosegundos)
                try? await Task.sleep(nanoseconds: 800_000_000)
            } else {
                // En caso de no tener animación, se muestra brevemente (300ms)
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            
            await MainActor.run {
                brillosEntity.removeFromParent()
            }
        } else {
            print("No se pudo cargar el modelo 'Brillos'")
        }
    }
}


// Define el componente que almacenará la Task de eliminación.
struct RemovalTaskComponent: Component {
    var task: Task<Void, Never>
}

// Extensión a Entity para agregar la propiedad removalTask
extension Entity {
    var removalTask: Task<Void, Never>? {
        get { self.components[RemovalTaskComponent.self]?.task }
        set {
            if let newValue = newValue {
                self.components.set(RemovalTaskComponent(task: newValue))
            }
        }
    }
}
extension Entity {
    /// Aplica el componente a la entidad y a todos sus hijos de forma recursiva.
    func propagate<T: Component>(component: T) {
        self.components.set(component)
        for child in self.children {
            child.propagate(component: component)
        }
    }
}

struct BalloonTypeComponent: Component {
    var type: String
}


