//
//  ImmersiveView.swift
//  Boom Ballon
//
//  Created by Vision Tartanga on 31/3/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            /*if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }*/
        
            if let skybox = createSkybox() {
                content.add(skybox)
            } else {
                print("Skybox creation failed")
            }
       

        }
    }
    private func createSkybox() -> Entity? {
        let largeSphere = MeshResource.generateSphere(radius: 2)
        var skyboxMaterial = UnlitMaterial()
        
        do {
            let texture = try TextureResource.load(named: "test")
            skyboxMaterial.color = .init(texture: .init(texture))
        } catch {
            print("Failed to create skybox material: \(error)")
            return nil
        }
        
        let skyboxEntity = Entity()
        skyboxEntity.components.set(ModelComponent(mesh: largeSphere, materials: [skyboxMaterial]))
        
        skyboxEntity.scale = .init(x: -10, y: 10, z: 10)
        return skyboxEntity
    }
}
/*
#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}*/
