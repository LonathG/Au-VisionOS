//
//  VisionFormWorkspaceView.swift
//  VisionForm 3D - Spatial Studio
//
//  Apple visionOS Spatial Computing 3D Modeling Interface
//

import SwiftUI
import RealityKit
import RealityKitContent
import simd

// MARK: - 3D Math & Data Types

public struct RealityKitStrokeDab: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var position: SIMD3<Float>
    public var color: UIColor
    public var radius: Float
    public var isSculpt: Bool

    public init(
        id: UUID = UUID(),
        position: SIMD3<Float>,
        color: UIColor,
        radius: Float,
        isSculpt: Bool = false
    ) {
        self.id = id
        self.position = position
        self.color = color
        self.radius = radius
        self.isSculpt = isSculpt
    }
}

public struct MaterialSpec: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var gradient: [Color]
    public var baseColor: Color
    public var uiColor: UIColor
    public var roughness: Double
    public var metallic: Double
    public var specular: Double
    public var description: String

    public init(
        id: String,
        name: String,
        gradient: [Color],
        baseColor: Color,
        uiColor: UIColor,
        roughness: Double,
        metallic: Double,
        specular: Double,
        description: String
    ) {
        self.id = id
        self.name = name
        self.gradient = gradient
        self.baseColor = baseColor
        self.uiColor = uiColor
        self.roughness = roughness
        self.metallic = metallic
        self.specular = specular
        self.description = description
    }
}

public enum BrushMode: String, CaseIterable, Sendable {
    case paint = "Paint"
    case sculpt = "Sculpt"
    case erase = "Erase"

    public var icon: String {
        switch self {
        case .paint: return "paintbrush.fill"
        case .sculpt: return "mountain.2.fill"
        case .erase: return "eraser.fill"
        }
    }
}


// MARK: - Main VisionForm Workspace View

public struct VisionFormWorkspaceView: View {
    // Spatial Tool & Material State
    @State private var activeTool: String = "Brush"
    @State private var activeMaterial: String = "Organic Polymer"
    @State private var roughness: Double = 43.0
    @State private var metallic: Double = 10.5
    @State private var specular: Double = 1.5
    @State private var isGizmoActive: Bool = true
    @State private var showInspector: Bool = true
    @State private var showLayersPanel: Bool = false
    @State private var showAIGenSheet: Bool = false
    @State private var rotationX: Double = -2.0
    @State private var rotationY: Double = -2.0
    @State private var polyCount: Int = 42804

    // Brush State
    @State private var isBrushActive: Bool = true
    @State private var brushMode: BrushMode = .paint
    @State private var brushOrbitMode: Bool = false
    @State private var activeStrokeColor: Color = .cyan
    @State private var activeStrokeSize: CGFloat = 14.0

    // Drag & Stroke Interaction Tracking
    @State private var lastDragLocation: CGPoint? = nil
    @State private var isCurrentlyDrawingStroke: Bool = false

    // RealityKit 3D Model Paint Strokes
    @State private var brushDabs: [RealityKitStrokeDab] = VisionFormWorkspaceView.defaultBrushDabs()
    @State private var currentStrokeDabs: [RealityKitStrokeDab] = []

    private var activeStrokeUIColor: UIColor {
        if activeStrokeColor == .cyan { return .cyan }
        if activeStrokeColor == Color(red: 1.0, green: 0.2, blue: 0.6) {
            return UIColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)
        }
        if activeStrokeColor == Color(red: 1.0, green: 0.8, blue: 0.1) {
            return UIColor(red: 1.0, green: 0.8, blue: 0.1, alpha: 1.0)
        }
        if activeStrokeColor == Color(red: 0.2, green: 0.9, blue: 0.4) {
            return UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
        }
        if activeStrokeColor == .white { return .white }
        return .cyan
    }

    public static func defaultBrushDabs() -> [RealityKitStrokeDab] {
        let r: Float = 0.0754
        let color = UIColor.cyan
        var dabs: [RealityKitStrokeDab] = []
        for i in 0...24 {
            let t = Float(i) / 24.0
            let phi = Float.pi * (0.32 + t * 0.36)
            let theta = Float.pi * (0.16 + t * 0.44)
            let x = r * sin(phi) * cos(theta)
            let y = r * sin(phi) * sin(theta)
            let z = r * cos(phi)
            dabs.append(RealityKitStrokeDab(position: SIMD3<Float>(x, y, z), color: color, radius: 0.0035))
        }
        return dabs
    }

    // Material Drag & Drop State
    @State private var isDropTargetActive: Bool = false
    @State private var materialAppliedToast: String? = nil

    // Model Layers State
    @State private var isPaintLayerVisible: Bool = true
    @State private var isWireframeLayerVisible: Bool = true
    @State private var isBaseMeshLayerVisible: Bool = true
    @State private var isGizmoLayerVisible: Bool = true
    @State private var isExplodedView: Bool = false
    @State private var layerOpacity: [String: Double] = [
        "paint": 1.0,
        "wireframe": 0.85,
        "base": 1.0,
        "gizmo": 0.7
    ]

    // Tools list
    private let tools: [(name: String, icon: String)] = [
        ("Layers", "square.stack.3d.up"),
        ("Sculpt", "paintbrush.pointed.fill"),
        ("Subdivide", "square.grid.3x3"),
        ("Symmetry", "arrow.left.and.right.righttriangle.left.righttriangle.right"),
        ("Bevel", "square.topthird.inset.filled"),
        ("Brush", "pencil.tip"),
        ("Boolean", "square.2.layers.3d")
    ]

    // Comprehensive Materials Presets for Drag & Drop
    private let materialsList: [MaterialSpec] = [
        MaterialSpec(
            id: "organic",
            name: "Organic Polymer",
            gradient: [Color(red: 0.45, green: 0.72, blue: 1.0), Color(red: 0.15, green: 0.45, blue: 0.95)],
            baseColor: .cyan,
            uiColor: UIColor(red: 0.3, green: 0.65, blue: 0.98, alpha: 1.0),
            roughness: 43.0,
            metallic: 10.5,
            specular: 1.5,
            description: "Biomimetic Azure Resin"
        ),
        MaterialSpec(
            id: "steel",
            name: "Brushed Steel",
            gradient: [Color(white: 0.88), Color(white: 0.55), Color(white: 0.25)],
            baseColor: Color(white: 0.75),
            uiColor: UIColor(red: 0.82, green: 0.85, blue: 0.9, alpha: 1.0),
            roughness: 28.0,
            metallic: 92.0,
            specular: 8.5,
            description: "Aerospace Titanium"
        ),
        MaterialSpec(
            id: "carbon",
            name: "Carbon Fiber",
            gradient: [Color(white: 0.32), Color(white: 0.15), Color(white: 0.05)],
            baseColor: Color(white: 0.2),
            uiColor: UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1.0),
            roughness: 65.0,
            metallic: 35.0,
            specular: 4.0,
            description: "Reinforced Composite"
        ),
        MaterialSpec(
            id: "gold",
            name: "Liquid Gold",
            gradient: [Color(red: 1.0, green: 0.88, blue: 0.35), Color(red: 0.85, green: 0.6, blue: 0.15)],
            baseColor: Color(red: 1.0, green: 0.8, blue: 0.2),
            uiColor: UIColor(red: 1.0, green: 0.82, blue: 0.22, alpha: 1.0),
            roughness: 12.0,
            metallic: 98.0,
            specular: 9.5,
            description: "Molten 24K Luster"
        ),
        MaterialSpec(
            id: "emerald",
            name: "Emerald Glass",
            gradient: [Color(red: 0.25, green: 0.95, blue: 0.6), Color(red: 0.05, green: 0.45, blue: 0.25)],
            baseColor: Color(red: 0.1, green: 0.8, blue: 0.4),
            uiColor: UIColor(red: 0.1, green: 0.85, blue: 0.45, alpha: 1.0),
            roughness: 6.0,
            metallic: 8.0,
            specular: 9.8,
            description: "Refractive Crystal"
        )
    ]

    private var currentMaterialSpec: MaterialSpec {
        materialsList.first(where: { $0.name == activeMaterial }) ?? materialsList[0]
    }

    public init() {}

    public var body: some View {
        ZStack {
            // Structured Studio Layout (Top Bar, Studio Workspace, Bottom Telemetry)
            VStack(spacing: 0) {
                // Top Navigation Bar
                topBar
                    .padding(.top, 20)
                    .padding(.horizontal, 32)

                // Middle Studio Row (Left Sidebar, Layers Panel, Centered 3D Viewport, Right Inspector)
                HStack(alignment: .center, spacing: 16) {
                    // Left Vertical Toolbar
                    leftToolbar
                        .padding(.leading, 32)

                    // Layers Floating Panel
                    if showLayersPanel {
                        layersPanel
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    Spacer(minLength: 16)

                    // 3D Viewport Centerpiece (Drop Destination for Materials)
                    viewportCenter

                    Spacer(minLength: 16)

                    // Right Procedural Inspector Pane
                    if showInspector {
                        rightInspector
                            .padding(.trailing, 32)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        reopenInspectorButton
                            .padding(.trailing, 32)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Telemetry Tag & Toast Notifications
                HStack {
                    telemetryTag
                        .padding(.leading, 36)
                        .padding(.bottom, 24)

                    if let toast = materialAppliedToast {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.cyan)
                            Text(toast)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .darkBlueTranslucentCapsule()
                        .padding(.bottom, 24)
                        .padding(.leading, 12)
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 760)
        // Bottom Floating Control Strip Ornament
        .ornament(attachmentAnchor: .scene(.bottom)) {
            bottomControlStrip
        }
        .sheet(isPresented: $showAIGenSheet) {
            aiGenSheet
        }
    }

    // MARK: - Reopen Inspector Button
    private var reopenInspectorButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showInspector = true
            }
        } label: {
            Label("Procedural", systemImage: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .darkBlueTranslucentCapsule()
    }

    // MARK: - Viewport Center 3D Model (RealityKit 3D PBR Model + Drop Destination)
    private var viewportCenter: some View {
        let modelRadius: Double = 110.0 // 220pt diameter, perfectly sized for workspace viewport

        return VStack(spacing: 12) {
            // Minimal Floating Brush HUD Palette
            if activeTool == "Brush" || activeTool == "Sculpt" {
                brushControlHUD
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                // Ambient floor contact shadow
                if isGizmoLayerVisible {
                    Ellipse()
                        .fill(Color.black.opacity(0.32))
                        .frame(width: 220, height: 44)
                        .blur(radius: 16)
                        .offset(y: 130)
                }

                // Spatial Ring Gizmo Layer (framed for 220pt model)
                if isGizmoActive && isGizmoLayerVisible {
                    Circle()
                        .strokeBorder(Color.blue.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                        .frame(width: 250, height: 250)
                        .scaleEffect(isExplodedView ? 1.25 : 1.0)
                    Circle()
                        .strokeBorder(Color.cyan.opacity(0.18), lineWidth: 1)
                        .frame(width: 300, height: 300)
                        .scaleEffect(isExplodedView ? 1.35 : 1.0)
                }

                // 3D Model & Interactive Layers Group
                ZStack {
                    // Layer 1: True 3D RealityKit Model with Dynamic PBR Material & 3D Surface Strokes
                    if isBaseMeshLayerVisible {
                        RealityView { content in
                            let root = Entity()
                            root.name = "StudioModelRoot"
                            // Position recessed in window so front pole touches window surface z = 0
                            root.position = SIMD3<Float>(0, 0, -0.075)

                            if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                                scene.name = "SceneEntity"
                                // Scene.usda has radius = 0.05m -> scale 1.5 gives 0.075m radius = 0.15m diameter (~220pt)
                                scene.scale = SIMD3<Float>(repeating: 1.5)
                                removeColliders(from: scene)
                                root.addChild(scene)
                            } else {
                                let mesh = MeshResource.generateSphere(radius: 0.075)
                                var pbr = PhysicallyBasedMaterial()
                                pbr.baseColor = .init(tint: UIColor(red: 0.3, green: 0.65, blue: 0.98, alpha: 1.0))
                                let sphere = ModelEntity(mesh: mesh, materials: [pbr])
                                sphere.name = "SphereFallback"
                                root.addChild(sphere)
                            }

                            // 3D Strokes Container attached directly to the model root
                            let strokesContainer = Entity()
                            strokesContainer.name = "StrokesContainer"
                            root.addChild(strokesContainer)

                            removeColliders(from: root)
                            content.add(root)
                        } update: { content in
                            guard let root = content.entities.first(where: { $0.name == "StudioModelRoot" }) else { return }

                            // 1. Update 3D Rotation on the actual RealityKit entity
                            let radX = Float(rotationX * .pi / 180.0)
                            let radY = Float(rotationY * .pi / 180.0)
                            let qX = simd_quatf(angle: radX, axis: SIMD3<Float>(1, 0, 0))
                            let qY = simd_quatf(angle: radY, axis: SIMD3<Float>(0, 1, 0))
                            root.transform.rotation = qY * qX

                            // 2. Exploded scale if active (centered and compact)
                            let baseScale: Float = isExplodedView ? 0.88 : 1.0
                            root.transform.scale = SIMD3<Float>(repeating: baseScale)

                            // 3. True 3D Physically-Based Material applied directly to the 3D Mesh
                            var pbr = PhysicallyBasedMaterial()
                            pbr.baseColor = .init(tint: currentMaterialSpec.uiColor)
                            pbr.roughness = .init(floatLiteral: Float(max(0.01, min(1.0, roughness / 100.0))))
                            pbr.metallic = .init(floatLiteral: Float(max(0.0, min(1.0, metallic / 100.0))))
                            pbr.specular = .init(floatLiteral: Float(max(0.0, min(1.0, specular / 10.0))))

                            applyMaterialToHierarchy(pbr, to: root)

                            // 4. Synchronize 3D paint stroke entities directly on the 3D model
                            if let strokesContainer = root.findEntity(named: "StrokesContainer") {
                                strokesContainer.isEnabled = isPaintLayerVisible
                                syncStrokeEntities(in: strokesContainer)
                            }
                        }
                        .frame(width: 340, height: 340)
                        .opacity(layerOpacity["base"] ?? 1.0)
                        .allowsHitTesting(false)
                    }

                    // Drop Target Animated Beacon when dragging material over model
                    if isDropTargetActive {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.cyan, Color.white, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, dash: [10, 6])
                            )
                            .frame(width: 250, height: 250)
                            .shadow(color: .cyan, radius: 20)
                            .overlay(
                                Text("Drop Material to Apply")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.75))
                                    .clipShape(Capsule())
                            )
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: 340, height: 340)
                .contentShape(Rectangle())
                // Drop Destination for materials
                .dropDestination(for: String.self) { items, location in
                    guard let materialName = items.first else { return false }
                    applyMaterial(named: materialName)
                    return true
                } isTargeted: { targeted in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDropTargetActive = targeted
                    }
                }
                // Painting Directly on the 3D Product & Smooth Orbiting
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let center = CGPoint(x: 170.0, y: 170.0)
                            let screenRadius: Float = 110.0
                            let dx = Float(value.location.x - center.x)
                            let dy = Float(value.location.y - center.y)
                            let r2 = dx * dx + dy * dy

                            // Check if drawing mode is active:
                            if isBrushActive && (activeTool == "Brush" || activeTool == "Sculpt") && !brushOrbitMode {
                                if isCurrentlyDrawingStroke || r2 <= screenRadius * screenRadius {
                                    isCurrentlyDrawingStroke = true

                                    // Normalize touch point to unit sphere
                                    let u: Float
                                    let v: Float
                                    if r2 <= screenRadius * screenRadius {
                                        u = dx / screenRadius
                                        v = -dy / screenRadius // +Y is UP in 3D RealityKit
                                    } else {
                                        let dist = sqrt(r2)
                                        u = (dx / dist) * 0.99
                                        v = (-dy / dist) * 0.99
                                    }
                                    let w = sqrt(max(0.0, 1.0 - (u * u + v * v)))
                                    let viewNormal = simd_normalize(SIMD3<Float>(u, v, w))

                                    // Transform from View Space to Model Object Space via inverse quaternion
                                    let radX = Float(rotationX * .pi / 180.0)
                                    let radY = Float(rotationY * .pi / 180.0)
                                    let qX = simd_quatf(angle: radX, axis: SIMD3<Float>(1, 0, 0))
                                    let qY = simd_quatf(angle: radY, axis: SIMD3<Float>(0, 1, 0))
                                    let qModel = qY * qX
                                    let qInv = simd_inverse(qModel)
                                    let objNormal = simd_normalize(simd_act(qInv, viewNormal))

                                    // Sphere radius is 0.075m. Position stroke bead on the 3D model surface:
                                    let dabRadius: Float = Float(activeStrokeSize) * 0.00032
                                    let surfacePos = objNormal * (0.0752 + dabRadius * 0.3)

                                    if brushMode == .erase {
                                        let eraseRadius: Float = 0.018
                                        brushDabs.removeAll { dab in
                                            simd_distance(dab.position, surfacePos) < eraseRadius
                                        }
                                    } else {
                                        if let last = currentStrokeDabs.last {
                                            let d = simd_distance(last.position, surfacePos)
                                            if d >= 0.0035 {
                                                let dab = RealityKitStrokeDab(
                                                    position: surfacePos,
                                                    color: activeStrokeUIColor,
                                                    radius: dabRadius,
                                                    isSculpt: brushMode == .sculpt
                                                )
                                                brushDabs.append(dab)
                                                currentStrokeDabs.append(dab)
                                                polyCount += (brushMode == .sculpt ? 32 : 12)
                                            }
                                        } else {
                                            let dab = RealityKitStrokeDab(
                                                position: surfacePos,
                                                color: activeStrokeUIColor,
                                                radius: dabRadius,
                                                isSculpt: brushMode == .sculpt
                                            )
                                            brushDabs.append(dab)
                                            currentStrokeDabs.append(dab)
                                            polyCount += (brushMode == .sculpt ? 32 : 12)
                                        }
                                    }
                                    lastDragLocation = nil
                                } else {
                                    // Dragged outside sphere without having started a stroke -> Orbit
                                    if let prev = lastDragLocation {
                                        let deltaX = Double(value.location.x - prev.x)
                                        let deltaY = Double(value.location.y - prev.y)
                                        rotationY += deltaX * 0.4
                                        rotationX -= deltaY * 0.4
                                    }
                                    lastDragLocation = value.location
                                }
                            } else {
                                // Brush is OFF or in Orbit Mode -> Smooth 3D Orbit
                                if let prev = lastDragLocation {
                                    let deltaX = Double(value.location.x - prev.x)
                                    let deltaY = Double(value.location.y - prev.y)
                                    rotationY += deltaX * 0.4
                                    rotationX -= deltaY * 0.4
                                }
                                lastDragLocation = value.location
                            }
                        }
                        .onEnded { _ in
                            isCurrentlyDrawingStroke = false
                            lastDragLocation = nil
                            currentStrokeDabs.removeAll()
                        }
                )
            }
            .frame(width: 340, height: 340)
        }
        .frame(maxWidth: 500, maxHeight: 560)
    }

    // MARK: - Synchronize RealityKit 3D Stroke Entities on Model Surface
    private func syncStrokeEntities(in container: Entity) {
        if container.children.count == brushDabs.count {
            return
        }

        let existing = container.children.count
        if existing < brushDabs.count {
            for i in existing..<brushDabs.count {
                let dab = brushDabs[i]
                let mesh = MeshResource.generateSphere(radius: dab.radius)
                var mat = PhysicallyBasedMaterial()
                mat.baseColor = .init(tint: dab.color)
                mat.roughness = dab.isSculpt ? 0.15 : 0.4
                mat.metallic = dab.isSculpt ? 0.35 : 0.05
                let entity = ModelEntity(mesh: mesh, materials: [mat])
                entity.position = dab.position
                entity.name = dab.id.uuidString
                container.addChild(entity)
            }
        } else {
            container.children.removeAll()
            for dab in brushDabs {
                let mesh = MeshResource.generateSphere(radius: dab.radius)
                var mat = PhysicallyBasedMaterial()
                mat.baseColor = .init(tint: dab.color)
                mat.roughness = dab.isSculpt ? 0.15 : 0.4
                mat.metallic = dab.isSculpt ? 0.35 : 0.05
                let entity = ModelEntity(mesh: mesh, materials: [mat])
                entity.position = dab.position
                entity.name = dab.id.uuidString
                container.addChild(entity)
            }
        }
    }

    // MARK: - Remove Colliders so RealityKit never blocks SwiftUI gestures
    private func removeColliders(from entity: Entity) {
        entity.components.remove(InputTargetComponent.self)
        entity.components.remove(CollisionComponent.self)
        for child in entity.children {
            removeColliders(from: child)
        }
    }

    // MARK: - Recursively Apply Material to RealityKit Entities
    private func applyMaterialToHierarchy(_ material: RealityKit.Material, to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = [material]
            entity.components.set(model)
        }
        for child in entity.children {
            applyMaterialToHierarchy(material, to: child)
        }
    }

    // MARK: - Minimal Apple visionOS Brush Floating HUD Palette
    private var brushControlHUD: some View {
        HStack(spacing: 10) {
            // Master Brush ON/OFF Toggle Icon
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isBrushActive.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isBrushActive ? "paintbrush.fill" : "paintbrush")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isBrushActive ? .cyan : .white.opacity(0.4))
                    Circle()
                        .fill(isBrushActive ? Color.green : Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                        .shadow(color: isBrushActive ? .green : .clear, radius: 4)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(isBrushActive ? Color.cyan.opacity(0.18) : Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isBrushActive ? Color.cyan.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(isBrushActive ? "Disable Brush" : "Enable Brush")

            if isBrushActive {
                Divider().frame(height: 16).background(Color.white.opacity(0.2))

                // Mode Icons: Paint | Sculpt | Erase
                HStack(spacing: 2) {
                    ForEach(BrushMode.allCases, id: \.self) { mode in
                        let isSelected = brushMode == mode
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                brushMode = mode
                                if mode == .sculpt { activeTool = "Sculpt" }
                                else if mode == .paint { activeTool = "Brush" }
                            }
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isSelected ? .cyan : .white.opacity(0.6))
                                .frame(width: 28, height: 28)
                                .background(isSelected ? Color.cyan.opacity(0.25) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(mode.rawValue)
                    }
                }
                .padding(2)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                Divider().frame(height: 16).background(Color.white.opacity(0.2))

                // Color Swatches
                HStack(spacing: 6) {
                    ForEach([
                        Color.cyan,
                        Color(red: 1.0, green: 0.2, blue: 0.6),
                        Color(red: 1.0, green: 0.8, blue: 0.1),
                        Color(red: 0.2, green: 0.9, blue: 0.4),
                        Color.white
                    ], id: \.self) { color in
                        let isSelected = activeStrokeColor == color
                        Button {
                            activeStrokeColor = color
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 15, height: 15)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                                )
                                .scaleEffect(isSelected ? 1.15 : 1.0)
                                .shadow(color: isSelected ? color.opacity(0.6) : .clear, radius: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().frame(height: 16).background(Color.white.opacity(0.2))

                // Brush Size: Visual Dot Indicators
                HStack(spacing: 3) {
                    ForEach([(8, 5.0), (14, 9.0), (22, 13.0)], id: \.0) { size, dotDiameter in
                        let isSelected = activeStrokeSize == CGFloat(size)
                        Button {
                            activeStrokeSize = CGFloat(size)
                        } label: {
                            Circle()
                                .fill(isSelected ? Color.cyan : Color.white.opacity(0.6))
                                .frame(width: dotDiameter, height: dotDiameter)
                                .frame(width: 24, height: 24)
                                .background(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("\(size)px Brush")
                    }
                }

                Divider().frame(height: 16).background(Color.white.opacity(0.2))

                // Orbit vs Draw Toggle
                Button {
                    brushOrbitMode.toggle()
                } label: {
                    Image(systemName: brushOrbitMode ? "arrow.triangle.2.circlepath" : "hand.draw.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(brushOrbitMode ? .purple : .cyan)
                        .frame(width: 28, height: 28)
                        .background(brushOrbitMode ? Color.purple.opacity(0.25) : Color.blue.opacity(0.2))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(brushOrbitMode ? Color.purple.opacity(0.5) : Color.blue.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(brushOrbitMode ? "Switch to Draw" : "Switch to Orbit View")

                // Clear Strokes Icon Button
                if !brushDabs.isEmpty {
                    Button {
                        withAnimation {
                            brushDabs.removeAll()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear All Strokes")
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .darkBlueTranslucentCapsule()
    }

    // MARK: - Apply Material Logic
    private func applyMaterial(named name: String) {
        if let found = materialsList.first(where: { $0.name == name }) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                activeMaterial = found.name
                roughness = found.roughness
                metallic = found.metallic
                specular = found.specular
                materialAppliedToast = "Applied \(found.name)"
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation {
                    materialAppliedToast = nil
                }
            }
        }
    }

    // MARK: - Layers Floating Panel
    private var layersPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundColor(.cyan)
                    Text("Model Layers")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showLayersPanel = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Exploded 3D Spatial Decomposition Toggle Card
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    isExplodedView.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isExplodedView ? "arrow.up.and.down.and.arrow.left.and.right" : "square.stack.3d.up")
                        .font(.system(size: 15))
                        .foregroundColor(isExplodedView ? .cyan : .white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(isExplodedView ? Color.cyan.opacity(0.2) : Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spatial Explode View")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text(isExplodedView ? "Layers separated in Z-depth" : "Unified collapsed mesh")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: isExplodedView ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isExplodedView ? .cyan : .white.opacity(0.3))
                }
                .padding(9)
                .background(isExplodedView ? Color.cyan.opacity(0.12) : Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isExplodedView ? Color.cyan.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Divider().background(Color.white.opacity(0.12))

            // Layers List
            VStack(spacing: 8) {
                // Layer 1: Surface Paint & Strokes
                layerRow(
                    title: "Surface Paint 3D",
                    subtitle: "\(brushDabs.count) 3D dabs on model",
                    icon: "paintbrush.pointed.fill",
                    iconColor: .cyan,
                    isVisible: $isPaintLayerVisible,
                    opacityKey: "paint"
                )

                // Layer 3: Base Geometry Core
                layerRow(
                    title: "Base Mesh Core",
                    subtitle: "\(activeMaterial) Surface",
                    icon: "circle.fill",
                    iconColor: .white,
                    isVisible: $isBaseMeshLayerVisible,
                    opacityKey: "base"
                )

                // Layer 4: Spatial Ring Gizmo
                layerRow(
                    title: "Spatial Ring Gizmo",
                    subtitle: "Axis & Meridian Guides",
                    icon: "circle.dashed",
                    iconColor: .cyan,
                    isVisible: $isGizmoLayerVisible,
                    opacityKey: "gizmo"
                )
            }

            Divider().background(Color.white.opacity(0.12))

            // Quick Actions
            HStack {
                Button {
                    withAnimation {
                        isPaintLayerVisible = true
                        isWireframeLayerVisible = true
                        isBaseMeshLayerVisible = true
                        isGizmoLayerVisible = true
                    }
                } label: {
                    Text("Show All Layers")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 270)
        .darkBlueTranslucentRounded(cornerRadius: 24)
    }

    private func layerRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        isVisible: Binding<Bool>,
        opacityKey: String
    ) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 9) {
                // Visibility Eye Toggle Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isVisible.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isVisible.wrappedValue ? .white : .white.opacity(0.3))
                        .frame(width: 26, height: 26)
                        .background(isVisible.wrappedValue ? Color.blue.opacity(0.25) : Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isVisible.wrappedValue ? .white : .white.opacity(0.4))
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()
            }

            // Opacity Slider if visible
            if isVisible.wrappedValue {
                HStack(spacing: 6) {
                    Text("Opacity")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Slider(
                        value: Binding(
                            get: { layerOpacity[opacityKey] ?? 1.0 },
                            set: { layerOpacity[opacityKey] = $0 }
                        ),
                        in: 0.1...1.0
                    )
                    .tint(iconColor)
                }
                .padding(.leading, 35)
            }
        }
        .padding(7)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Telemetry Tag
    private var telemetryTag: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isBrushActive ? Color.cyan : Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: isBrushActive ? .cyan : .green, radius: 4)

            Text(
                activeTool == "Brush"
                    ? "Tool: Brush (\(isBrushActive ? "ON" : "OFF")) | 3D Dabs: \(brushDabs.count) | Size: \(Int(activeStrokeSize))px"
                    : (activeTool == "Layers" || showLayersPanel
                        ? "Tool: Layers | Mode: \(isExplodedView ? "Exploded 3D" : "Unified") | Active Layers: 3"
                        : "Material: \(activeMaterial) | Poly Count: \(polyCount.formatted()) | X,Y,Z: (\(Int(rotationX)), \(Int(rotationY)), 300)")
            )
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .darkBlueTranslucentCapsule()
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "cube.fill")
                    .foregroundColor(.blue)
                Text("VisionForm")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.2))

            Text("Sculpt_NeoStructure_v4.vfm")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Text("100%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())

            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Text("Live Sync")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.cyan)
            }

            Spacer()

            ToggleImmersiveSpaceButton()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .darkBlueTranslucentCapsule()
    }

    // MARK: - Left Vertical Toolbar
    private var leftToolbar: some View {
        VStack(spacing: 12) {
            ForEach(tools, id: \.name) { tool in
                let isActive = (activeTool == tool.name && (tool.name != "Brush" || isBrushActive)) || (tool.name == "Layers" && showLayersPanel)
                Button {
                    if tool.name == "Brush" {
                        if activeTool == "Brush" {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isBrushActive.toggle()
                            }
                        } else {
                            activeTool = "Brush"
                            isBrushActive = true
                            brushMode = .paint
                            brushOrbitMode = false
                        }
                    } else if tool.name == "Layers" || tool.name == "Boolean" {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showLayersPanel.toggle()
                        }
                        activeTool = tool.name
                    } else if tool.name == "Sculpt" {
                        activeTool = "Sculpt"
                        isBrushActive = true
                        brushMode = .sculpt
                        brushOrbitMode = false
                    } else {
                        activeTool = tool.name
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 4) {
                            Image(systemName: tool.icon)
                                .font(.system(size: 18))
                                .foregroundColor(isActive ? .cyan : .white.opacity(0.75))
                        }
                        .frame(width: 44, height: 44)
                        .background(
                            isActive
                                ? Color.blue.opacity(0.35)
                                : Color.white.opacity(0.04)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isActive ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: isActive ? Color.cyan.opacity(0.3) : .clear, radius: 8)

                        if tool.name == "Brush" && isBrushActive {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                                .offset(x: -3, y: 3)
                                .shadow(color: .green, radius: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(tool.name)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .darkBlueTranslucentRounded(cornerRadius: 28)
    }

    // MARK: - Right Inspector Card (Draggable Material Cards)
    private var rightInspector: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Procedural")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Shader & Surface")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showInspector = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Material Swatches: Drag and Droppable to 3D Model
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("MATERIALS (DRAG TO MODEL)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Image(systemName: "hand.draw")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan.opacity(0.7))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(materialsList) { mat in
                            let isSelected = activeMaterial == mat.name
                            Button {
                                applyMaterial(named: mat.name)
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: mat.gradient,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? Color.cyan : Color.white.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                                        )
                                        .shadow(color: isSelected ? Color.cyan.opacity(0.5) : .black.opacity(0.3), radius: 8)

                                    Text(mat.name)
                                        .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? .cyan : .white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                }
                                .frame(width: 72)
                                .padding(.vertical, 8)
                                .background(
                                    isSelected ? Color.blue.opacity(0.15) : Color.white.opacity(0.04)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .draggable(mat.name) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(LinearGradient(colors: mat.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 24, height: 24)
                                    Text(mat.name)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.85))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.cyan, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            // Precision Sliders (Sync live with active 3D material)
            VStack(spacing: 16) {
                sliderRow(title: "Roughness", value: $roughness, range: 0...100, spec: "%.1f")
                sliderRow(title: "Metallic", value: $metallic, range: 0...100, spec: "%.1f")
                sliderRow(title: "Specular", value: $specular, range: 0...10, spec: "%.1f")
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Action Button
            Button {
                // Synthesize surface maps
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.cyan)
                    Text("Synthesize Surface Map")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 290)
        .darkBlueTranslucentRounded(cornerRadius: 28)
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, spec: String) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(String(format: spec, value.wrappedValue))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Slider(value: value, in: range)
                .tint(.blue)
        }
    }

    // MARK: - Bottom Floating Control Strip
    private var bottomControlStrip: some View {
        VStack(spacing: 6) {
            // Main Pill Bar
            HStack(spacing: 12) {
                Button {
                    // Undo last 3D stroke dabs
                    if !brushDabs.isEmpty {
                        withAnimation {
                            let countToRemove = min(8, brushDabs.count)
                            brushDabs.removeLast(countToRemove)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .disabled(brushDabs.isEmpty)

                Button {
                    // Redo action
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16))
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())

                Button {
                    isGizmoActive.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "grid")
                        Text("Gizmo")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isGizmoActive ? .cyan.opacity(0.3) : .white.opacity(0.1))

                Button {
                    // Render
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.aperture")
                        Text("Render")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)

                Button {
                    showAIGenSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("AI Gen Preview")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue.opacity(0.35))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .darkBlueTranslucentCapsule()

            // Three subtle pagination dots below the pill
            HStack(spacing: 6) {
                Circle().fill(Color.white).frame(width: 5, height: 5)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .darkBlueTranslucentCapsule()
        }
        .padding(.bottom, 16)
    }

    // MARK: - AI Gen Modal Sheet
    private var aiGenSheet: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Spatial AI 3D Mesh Generator", systemImage: "brain.head.profile")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Done") {
                    showAIGenSheet = false
                }
            }

            Text("Describe the volumetric geometry or spatial structure you wish to generate via neural diffusion:")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))

            TextEditor(text: .constant("Aerodynamic biomimetic chassis with organic Voronoi lattice cooling chambers and titanium mounting vertices."))
                .frame(height: 100)
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                showAIGenSheet = false
            } label: {
                Text("Generate Volumetric Mesh")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding(30)
        .frame(width: 480)
        .darkBlueTranslucentRounded(cornerRadius: 32)
    }
}


// MARK: - Dark Blue Translucent Panel Styling
extension View {
    func darkBlueTranslucentCapsule() -> some View {
        self
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 10/255, green: 22/255, blue: 46/255).opacity(0.82),
                                    Color(red: 6/255, green: 14/255, blue: 32/255).opacity(0.86)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.35),
                                Color.white.opacity(0.18),
                                Color.blue.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
    }

    func darkBlueTranslucentRounded(cornerRadius: CGFloat = 28) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 10/255, green: 22/255, blue: 46/255).opacity(0.84),
                                    Color(red: 6/255, green: 14/255, blue: 32/255).opacity(0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.35),
                                Color.white.opacity(0.18),
                                Color.blue.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
    }
}

#Preview(windowStyle: .automatic) {
    VisionFormWorkspaceView()
        .environment(AppModel())
}
