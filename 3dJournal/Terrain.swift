//
//  Terrain.swift
//  3dJournal
//
//  Created by Trevor Clute on 4/10/25.
//

import Foundation
import SceneKit

class Terrain {
    var terrainNodes: Set<String> = []
    var particleNodes: [String: SCNNode] = [:]
    var scene: SCNScene
    var worldCraters: [(Float, Float, Float)] = []
    static var gridSize = 200

    init(scene: SCNScene) {
        self.scene = scene
    }

    func getWorldHeight(x: Float, z: Float)
        -> Float
    {
        var height: Float = 0.0

        for (cx, cz, cr) in worldCraters {
            let dx = x - cx
            let dz = z - cz
            let dist = sqrt(dx * dx + dz * dz)

            let radius: Float = cr
            if dist < radius {
                height -= 1
            }
        }

        return height
    }

    func getHeight(x: Float, z: Float, craters: [(Float, Float, Float)])
        -> Float
    {
        var height: Float = 0.0

        for (cx, cz, cr) in craters {
            let dx = x - cx
            let dz = z - cz
            let dist = sqrt(dx * dx + dz * dz)

            let radius: Float = cr
            if dist < radius {
                height -= 1
            }
        }

        return height + Float.random(in: -0.1...0.1)
    }

    func generateCraterCenter(
        craterCount: Int, craters: inout [(Float, Float, Float)], x: Int, z: Int
    ) {
        // Generate crater centers
        for _ in 0..<craterCount {
            let nr = Float.random(in: 0.01..<0.15)
            let padding = nr * 1.1
            let nx = Float.random(in: padding..<(1 - padding))
            let nz = Float.random(in: padding..<(1 - padding))
            craters.append((nx, nz, nr))
            let worldX =
                Float(x) * Float(Terrain.gridSize) + Float(nx)
                * Float(Terrain.gridSize)
            let worldZ =
                Float(z) * Float(Terrain.gridSize) + Float(nz)
                * Float(Terrain.gridSize)
            let worldR = Float(nr) * Float(Terrain.gridSize)
            DispatchQueue.main.async {
                self.worldCraters.append((worldX, worldZ, worldR))
            }
        }
    }

    func generateNode(
        colors: [SCNVector4], vertices: [SCNVector3], indices: [Int32], x: Int,
        z: Int
    ) -> SCNNode {
        // Create SceneKit geometry
        let colorData = Data(
            bytes: colors, count: colors.count * MemoryLayout<SCNVector4>.size)
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector4>.size
        )
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexData = Data(
            bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData, primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<Int32>.size)

        let geometry = SCNGeometry(
            sources: [vertexSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.shininess = 0.1
        material.roughness.contents = 1.0
        material.metalness.contents = 0.0
        material.lightingModel = .physicallyBased
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(
            x * (Terrain.gridSize - 2), 0, z * (Terrain.gridSize - 2))
        return node
    }

    func generateCraterTerrainNode(
        scale: Float = 2.0, craterCount: Int = 25, x: Int,
        z: Int
    ){
        let key = "\(x),\(z)"
        if self.terrainNodes.contains(key) {
            return
        }
        self.terrainNodes.insert(key)

        DispatchQueue.global(qos: .background).async {

            var vertices: [SCNVector3] = []
            var indices: [Int32] = []
            var craters: [(Float, Float, Float)] = []

            self.generateCraterCenter(
                craterCount: craterCount, craters: &craters, x: x, z: z)

            // Generate vertices with craters
            var colors: [SCNVector4] = []

            for z in 0..<Terrain.gridSize {
                for x in 0..<Terrain.gridSize {
                    let nx = Float(x) / Float(Terrain.gridSize)
                    let nz = Float(z) / Float(Terrain.gridSize)

                    let height =
                        (self.getHeight(x: nx, z: nz, craters: craters) * scale)
                    vertices.append(SCNVector3(Float(x), height, Float(z)))

                    let t = max(0, ((height / 2) + 5)) / 30
                    let r = t
                    let g = t
                    let b = t
                    colors.append(SCNVector4(r, g, b, 1.0))
                }
            }

            // Create triangle indices
            for z in 0..<Terrain.gridSize - 1 {
                for x in 0..<Terrain.gridSize - 1 {
                    let topLeft = Int32(z * Terrain.gridSize + x)
                    let topRight = Int32(z * Terrain.gridSize + x + 1)
                    let bottomLeft = Int32((z + 1) * Terrain.gridSize + x)
                    let bottomRight = Int32((z + 1) * Terrain.gridSize + x + 1)

                    indices += [topLeft, bottomLeft, topRight]
                    indices += [topRight, bottomLeft, bottomRight]
                }
            }

            let node = self.generateNode(
                colors: colors, vertices: vertices, indices: indices, x: x, z: z
            )
            DispatchQueue.main.async {
                self.scene.rootNode.addChildNode(node)
            }

        }
    }

    func generateSurroundingTiles(x: Int, z: Int) {
        self.generateCraterTerrainNode(x: x, z: z)
        self.generateCraterTerrainNode(x: x + 1, z: z)
        self.generateCraterTerrainNode(x: x - 1, z: z)
        self.generateCraterTerrainNode(x: x + 1, z: z + 1)
        self.generateCraterTerrainNode(x: x - 1, z: z + 1)
        self.generateCraterTerrainNode(x: x + 1, z: z - 1)
        self.generateCraterTerrainNode(x: x - 1, z: z - 1)
        self.generateCraterTerrainNode(x: x, z: z - 1)
        self.generateCraterTerrainNode(x: x, z: z + 1)
    }
}
