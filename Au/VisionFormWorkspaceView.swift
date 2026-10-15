//
//  VisionFormWorkspaceView.swift
//  VisionForm 3D - Spatial Studio
//
//  Apple visionOS Spatial Computing 3D Modeling Interface
//

import SwiftUI
import RealityKit
import RealityKitContent

// MARK: - 3D Math & Data Types

public struct Point3D: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct Surface3DStroke: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var points: [Point3D]
    public var color: Color
    public var size: CGFloat
    public var isSculpt: Bool

    public init(id: UUID = UUID(), points: [Point3D], color: Color, size: CGFloat, isSculpt: Bool) {
        self.id = id
        self.points = points
        self.color = color
        self.size = size
        self.isSculpt = isSculpt
    }
}

public struct MaterialSpec: Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var gradient: [Color]
    public var baseColor: Color
    public var roughness: Double
    public var metallic: Double
    public var specular: Double
    public var description: String

    public init(
        id: String,
        name: String,
        gradient: [Color],
        baseColor: Color,
        roughness: Double,
        metallic: Double,
        specular: Double,
        description: String
    ) {
        self.id = id
        self.name = name
        self.gradient = gradient
        self.baseColor = baseColor
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

// MARK: - 3D Projection Helpers

/// Projects a 3D point from object space to view space given model rotation angles (in degrees)
public func projectToView(_ point: Point3D, rotX: Double, rotY: Double) -> (x: Double, y: Double, z: Double) {
    let alpha = rotX * (.pi / 180.0)
    let beta = rotY * (.pi / 180.0)

    // Forward X rotation
    let x1 = point.x
    let y1 = point.y * cos(alpha) - point.z * sin(alpha)
    let z1 = point.y * sin(alpha) + point.z * cos(alpha)

    // Forward Y rotation
    let xCur = x1 * cos(beta) + z1 * sin(beta)
    let zCur = -x1 * sin(beta) + z1 * cos(beta)
    let yCur = y1

    return (x: xCur, y: yCur, z: zCur)
}

/// Inverses a 2D screen touch on the front hemisphere back to 3D object space coordinates
public func screenToSphere(screenPoint: CGPoint, rotX: Double, rotY: Double, radius: Double) -> Point3D? {
    let dx = Double(screenPoint.x - 170.0)
    let dy = Double(screenPoint.y - 170.0)
    let r2 = dx * dx + dy * dy
    guard r2 <= radius * radius else { return nil }
    let dz = sqrt(max(0.0, radius * radius - r2))

    let alpha = rotX * (.pi / 180.0)
    let beta = rotY * (.pi / 180.0)

    // Inverse Y rotation (by -beta)
    let x1 = dx * cos(beta) - dz * sin(beta)
    let z1 = dx * sin(beta) + dz * cos(beta)
    let y1 = dy

    // Inverse X rotation (by -alpha)
    let xObj = x1
    let yObj = y1 * cos(alpha) + z1 * sin(alpha)
    let zObj = -y1 * sin(alpha) + z1 * cos(alpha)

    return Point3D(x: xObj, y: yObj, z: zObj)
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

    // Requirement 2: Brush Toggle on/off state
    @State private var isBrushActive: Bool = true
    @State private var brushMode: BrushMode = .paint
    @State private var brushOrbitMode: Bool = false
    @State private var activeStrokeColor: Color = .cyan
    @State private var activeStrokeSize: CGFloat = 14.0
    @State private var active3DStrokePoints: [Point3D] = []

    // Requirement 3: 3D Surface Strokes (drawn in 3D product space)
    @State private var strokes3D: [Surface3DStroke] = [
        Surface3DStroke(
            points: (0...24).map { i -> Point3D in
                let t = Double(i) / 24.0
                let angle = (t - 0.5) * 1.7
                let radius = 155.0
                let x = sin(angle) * radius * 0.8
                let y = (t - 0.5) * 150.0
                let z = sqrt(max(0.0, radius * radius - x * x - y * y))
                return Point3D(x: x, y: y, z: z)
            },
            color: .cyan,
            size: 14.0,
            isSculpt: false
        )
    ]

    // Requirement 1: Drag & Drop Material State
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

    // Tools list matching Stitch specifications
    private let tools: [(name: String, icon: String)] = [
        ("Layers", "square.stack.3d.up"),
        ("Sculpt", "paintbrush.pointed.fill"),
        ("Subdivide", "square.grid.3x3"),
        ("Symmetry", "arrow.left.and.right.righttriangle.left.righttriangle.right"),
        ("Bevel", "square.topthird.inset.filled"),
        ("Brush", "pencil.tip"),
        ("Boolean", "square.2.layers.3d")
    ]

    // Comprehensive Materials List for Drag & Drop
    private let materialsList: [MaterialSpec] = [
        MaterialSpec(
            id: "organic",
            name: "Organic Polymer",
            gradient: [Color(red: 0.45, green: 0.72, blue: 1.0), Color(red: 0.15, green: 0.45, blue: 0.95)],
            baseColor: .cyan,
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
                    // Left Vertical Toolbar - safely inset with 32pt padding
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

    // MARK: - Viewport Center 3D Model (with 3D Drawing & Material Drop Destination)
    private var viewportCenter: some View {
        VStack(spacing: 12) {
            // Floating Brush HUD Palette (shows when Brush/Sculpt is selected)
            if activeTool == "Brush" || activeTool == "Sculpt" {
                brushControlHUD
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                // Ambient floor contact shadow
                if isGizmoLayerVisible {
                    Ellipse()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 320, height: 60)
                        .blur(radius: 20)
                        .offset(y: 180)
                }

                // Spatial Ring Gizmo Layer
                if isGizmoActive && isGizmoLayerVisible {
                    Circle()
                        .strokeBorder(Color.blue.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                        .frame(width: 360, height: 360)
                        .scaleEffect(isExplodedView ? 1.32 : 1.0)
                    Circle()
                        .strokeBorder(Color.cyan.opacity(0.15), lineWidth: 1)
                        .frame(width: 440, height: 440)
                        .scaleEffect(isExplodedView ? 1.44 : 1.0)
                }

                // 3D Model & Interactive Layers Group
                ZStack {
                    // Layer 3: Dynamic Volumetric Material Surface (Updates on Drop)
                    if isBaseMeshLayerVisible {
                        DynamicMaterialSphereView(
                            material: currentMaterialSpec,
                            roughness: roughness,
                            metallic: metallic,
                            specular: specular,
                            isDropTarget: isDropTargetActive
                        )
                        .opacity(layerOpacity["base"] ?? 1.0)
                        .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
                        .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))

                        // RealityKit scene overlay with soft blend
                        Model3D(named: "Scene", bundle: realityKitContentBundle) { model in
                            model
                                .resizable()
                                .scaledToFit()
                                .frame(width: 340, height: 340)
                                .opacity(0.25)
                                .blendMode(.multiply)
                        } placeholder: {
                            EmptyView()
                        }
                        .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
                        .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
                    }

                    // Layer 2: Topology Wireframe Grid
                    if isWireframeLayerVisible {
                        WireframeOverlayView(subdivisions: 10)
                            .frame(width: 340, height: 340)
                            .scaleEffect(isExplodedView ? 1.22 : 1.0)
                            .opacity(layerOpacity["wireframe"] ?? 0.85)
                            .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
                            .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
                            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExplodedView)
                    }

                    // Layer 1: True 3D Surface Paint & Sculpt Strokes
                    if isPaintLayerVisible {
                        Surface3DCanvasView(
                            strokes: strokes3D,
                            activePoints: active3DStrokePoints,
                            activeColor: activeStrokeColor,
                            activeSize: activeStrokeSize,
                            rotX: rotationX,
                            rotY: rotationY,
                            radius: 155.0
                        )
                        .frame(width: 340, height: 340)
                        .scaleEffect(isExplodedView ? 1.12 : 1.0)
                        .opacity(layerOpacity["paint"] ?? 1.0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExplodedView)
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
                            .frame(width: 360, height: 360)
                            .shadow(color: .cyan, radius: 24)
                            .overlay(
                                Text("Drop Material to Apply")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.75))
                                    .clipShape(Capsule())
                            )
                    }
                }
                .contentShape(Circle())
                // Requirement 1: Make 3D model a Drop Destination for materials
                .dropDestination(for: String.self) { items, location in
                    guard let materialName = items.first else { return false }
                    applyMaterial(named: materialName)
                    return true
                } isTargeted: { targeted in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDropTargetActive = targeted
                    }
                }
                // Requirement 2 & 3: Painting in 3D Product Space & Orbiting
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let radius = 155.0
                            let center = CGPoint(x: 170.0, y: 170.0)
                            let dx = Double(value.location.x - center.x)
                            let dy = Double(value.location.y - center.y)
                            let r2 = dx * dx + dy * dy

                            // If brush is TOGGLED ON and not in orbit-only mode:
                            if isBrushActive && (activeTool == "Brush" || activeTool == "Sculpt") && !brushOrbitMode {
                                if r2 <= radius * radius {
                                    // Map screen point to 3D surface point on sphere
                                    if let pt3D = screenToSphere(
                                        screenPoint: value.location,
                                        rotX: rotationX,
                                        rotY: rotationY,
                                        radius: radius
                                    ) {
                                        if brushMode == .erase {
                                            // Erase nearest 3D strokes
                                            strokes3D.removeAll { stroke in
                                                stroke.points.contains { p in
                                                    let dist = hypot(p.x - pt3D.x, hypot(p.y - pt3D.y, p.z - pt3D.z))
                                                    return dist < Double(activeStrokeSize) * 1.5
                                                }
                                            }
                                        } else {
                                            active3DStrokePoints.append(pt3D)
                                        }
                                    }
                                } else {
                                    // Dragging outside the sphere orbits view
                                    rotationY += Double(value.translation.width) * 0.02
                                    rotationX -= Double(value.translation.height) * 0.02
                                }
                            } else {
                                // Default orbit gesture (when brush is OFF or in Orbit mode)
                                rotationY += Double(value.translation.width) * 0.04
                                rotationX -= Double(value.translation.height) * 0.04
                            }
                        }
                        .onEnded { value in
                            if isBrushActive && !active3DStrokePoints.isEmpty {
                                let stroke = Surface3DStroke(
                                    points: active3DStrokePoints,
                                    color: activeStrokeColor,
                                    size: activeStrokeSize,
                                    isSculpt: brushMode == .sculpt
                                )
                                strokes3D.append(stroke)
                                active3DStrokePoints = []
                                polyCount += (brushMode == .sculpt ? 320 : 84)
                            }
                        }
                )
            }
        }
        .frame(maxWidth: 500, maxHeight: 560)
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

                // Color Swatches (Clean, crisp 15pt circles)
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

                // Brush Size: Visual Dot Indicators (Small, Medium, Large)
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

                // Orbit vs Draw Toggle (Compact Icon)
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
                if !strokes3D.isEmpty {
                    Button {
                        withAnimation {
                            strokes3D.removeAll()
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

    // MARK: - Requirement 1: Apply Material Logic
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
                    subtitle: "\(strokes3D.count) 3D strokes",
                    icon: "paintbrush.pointed.fill",
                    iconColor: .cyan,
                    isVisible: $isPaintLayerVisible,
                    opacityKey: "paint"
                )

                // Layer 2: Topology Wireframe
                layerRow(
                    title: "Topology Wireframe",
                    subtitle: "Subdiv Level 2 | 42k polys",
                    icon: "grid",
                    iconColor: .blue,
                    isVisible: $isWireframeLayerVisible,
                    opacityKey: "wireframe"
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
                    ? "Tool: Brush (\(isBrushActive ? "ON" : "OFF")) | 3D Strokes: \(strokes3D.count) | Size: \(Int(activeStrokeSize))px"
                    : (activeTool == "Layers" || showLayersPanel
                        ? "Tool: Layers | Mode: \(isExplodedView ? "Exploded 3D" : "Unified") | Active Layers: 4"
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

    // MARK: - Left Vertical Toolbar (with Brush Toggle on Click)
    private var leftToolbar: some View {
        VStack(spacing: 12) {
            ForEach(tools, id: \.name) { tool in
                let isActive = (activeTool == tool.name && (tool.name != "Brush" || isBrushActive)) || (tool.name == "Layers" && showLayersPanel)
                Button {
                    if tool.name == "Brush" {
                        if activeTool == "Brush" {
                            // Requirement 2: Toggle Brush on and off on repeated click
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

                        // Brush ON indicator dot badge
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

    // MARK: - Right Inspector Card (Requirement 1: Draggable Material Cards)
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

            // Material Swatches: Requirement 1 - Drag and Droppable to 3D Model
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
                            // Requirement 1: Make each material draggable to the 3D model
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

            // Precision Sliders (Sync live with active material)
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
                    // Undo last 3D stroke
                    if !strokes3D.isEmpty {
                        withAnimation {
                            _ = strokes3D.removeLast()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .disabled(strokes3D.isEmpty)

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

// MARK: - Dynamic Volumetric Material Surface View (Updates on Material Drop)
public struct DynamicMaterialSphereView: View {
    public var material: MaterialSpec
    public var roughness: Double
    public var metallic: Double
    public var specular: Double
    public var isDropTarget: Bool

    public init(
        material: MaterialSpec,
        roughness: Double,
        metallic: Double,
        specular: Double,
        isDropTarget: Bool
    ) {
        self.material = material
        self.roughness = roughness
        self.metallic = metallic
        self.specular = specular
        self.isDropTarget = isDropTarget
    }

    public var body: some View {
        ZStack {
            // Base Material Gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: material.gradient,
                        center: UnitPoint(x: 0.32, y: 0.3),
                        startRadius: 15,
                        endRadius: 170
                    )
                )

            // Ambient Occlusion / Darker underside shadow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.clear, Color.black.opacity(0.65)],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 50,
                        endRadius: 170
                    )
                )

            // Metallic sheen layer
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(metallic / 100.0 * 0.4),
                            Color.clear,
                            Color.black.opacity(metallic / 100.0 * 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)

            // Specular Reflection Highlight (Controlled by Roughness & Specular)
            let highlightSize = max(10.0, (100.0 - roughness) * 0.7)
            let highlightOpacity = min(1.0, (specular / 10.0) * 0.95 + 0.05)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(highlightOpacity),
                            Color.white.opacity(highlightOpacity * 0.3),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.28, y: 0.26),
                        startRadius: 2,
                        endRadius: highlightSize
                    )
                )
                .blendMode(.screen)

            // Outer Fresnel Specular Rim Stroke
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.75),
                            material.baseColor.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .frame(width: 340, height: 340)
        .clipShape(Circle())
    }
}

// MARK: - Topology Wireframe Overlay View (Single Canvas Draw Call)
public struct WireframeOverlayView: View {
    var subdivisions: Int = 10

    public init(subdivisions: Int = 10) {
        self.subdivisions = subdivisions
    }

    public var body: some View {
        Canvas { context, size in
            let w = Double(size.width)
            let h = Double(size.height)

            // Outer glowing rim
            context.stroke(
                Circle().path(in: CGRect(x: 0, y: 0, width: w, height: h)),
                with: .color(Color.cyan.opacity(0.55)),
                lineWidth: 1.5
            )

            // Latitude rings
            for i in 1..<subdivisions {
                let norm = Double(i) / Double(subdivisions)
                let angle = norm * .pi
                let yOffset = cos(angle) * (h / 2.0)
                let ringWidth = sin(angle) * w
                let ringHeight = max(2.0, ringWidth * 0.28)
                let rect = CGRect(
                    x: (w - ringWidth) / 2.0,
                    y: (h / 2.0) + yOffset - (ringHeight / 2.0),
                    width: ringWidth,
                    height: ringHeight
                )
                context.stroke(
                    Ellipse().path(in: rect),
                    with: .color(Color.cyan.opacity(0.28)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }

            // Longitude curves
            for i in 0..<subdivisions {
                let angle = Double(i) * (.pi / Double(subdivisions))
                let ringWidth = max(2.0, sin(angle) * w)
                let rect = CGRect(
                    x: (w - ringWidth) / 2.0,
                    y: 0.0,
                    width: ringWidth,
                    height: h
                )
                context.stroke(
                    Ellipse().path(in: rect),
                    with: .color(Color.blue.opacity(0.22)),
                    lineWidth: 1
                )
            }
        }
    }
}

// MARK: - Requirement 3: True 3D Surface Strokes Canvas View (Rotates in 3D & Clips to Horizon)
public struct Surface3DCanvasView: View {
    public var strokes: [Surface3DStroke]
    public var activePoints: [Point3D]
    public var activeColor: Color
    public var activeSize: CGFloat
    public var rotX: Double
    public var rotY: Double
    public var radius: Double

    public init(
        strokes: [Surface3DStroke],
        activePoints: [Point3D],
        activeColor: Color,
        activeSize: CGFloat,
        rotX: Double,
        rotY: Double,
        radius: Double = 155.0
    ) {
        self.strokes = strokes
        self.activePoints = activePoints
        self.activeColor = activeColor
        self.activeSize = activeSize
        self.rotX = rotX
        self.rotY = rotY
        self.radius = radius
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)

            // Render all completed 3D strokes
            for stroke in strokes {
                draw3DStroke(
                    stroke.points,
                    color: stroke.color,
                    size: stroke.size,
                    isSculpt: stroke.isSculpt,
                    in: &context,
                    center: center
                )
            }

            // Render in-progress 3D stroke
            if !activePoints.isEmpty {
                draw3DStroke(
                    activePoints,
                    color: activeColor,
                    size: activeSize,
                    isSculpt: false,
                    in: &context,
                    center: center
                )
            }
        }
        .frame(width: 340, height: 340)
        .clipShape(Circle())
    }

    private func draw3DStroke(
        _ points: [Point3D],
        color: Color,
        size: CGFloat,
        isSculpt: Bool,
        in context: inout GraphicsContext,
        center: CGPoint
    ) {
        guard !points.isEmpty else { return }

        // Project all points into current view coordinates
        let projected = points.map { pt -> (screen: CGPoint, z: Double, normDot: Double) in
            let proj = projectToView(pt, rotX: rotX, rotY: rotY)
            let scr = CGPoint(x: center.x + proj.x, y: center.y + proj.y)
            let lightDot = (-proj.x * 0.3 - proj.y * 0.4 + proj.z * 0.86) / max(1.0, radius)
            return (screen: scr, z: proj.z, normDot: max(0.0, lightDot))
        }

        // Single point dab
        if projected.count == 1 {
            let p = projected[0]
            if p.z > -2.0 {
                let depthScale = max(0.4, (p.z + radius) / (2.0 * radius))
                let dotSize = size * depthScale
                let rect = CGRect(
                    x: p.screen.x - dotSize / 2,
                    y: p.screen.y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Circle().path(in: rect), with: .color(color))
                if isSculpt {
                    let hlRect = CGRect(
                        x: p.screen.x - dotSize / 4,
                        y: p.screen.y - dotSize / 4,
                        width: dotSize / 2,
                        height: dotSize / 2
                    )
                    context.fill(Circle().path(in: hlRect), with: .color(.white.opacity(0.85 * p.normDot)))
                }
            }
            return
        }

        // Draw line segments on visible front hemisphere (z > -2.0)
        var path = Path()
        var isDrawing = false

        for i in 0..<(projected.count - 1) {
            let p1 = projected[i]
            let p2 = projected[i + 1]

            if p1.z > -2.0 && p2.z > -2.0 {
                if !isDrawing {
                    path.move(to: p1.screen)
                    isDrawing = true
                }
                path.addLine(to: p2.screen)
            } else if p1.z > -2.0 && p2.z <= -2.0 {
                // Crossing from front to back: clip segment at sphere horizon
                let denominator = p1.z - p2.z
                let t = denominator != 0 ? (p1.z + 2.0) / denominator : 0.5
                let clipX = p1.screen.x + t * (p2.screen.x - p1.screen.x)
                let clipY = p1.screen.y + t * (p2.screen.y - p1.screen.y)
                if !isDrawing {
                    path.move(to: p1.screen)
                }
                path.addLine(to: CGPoint(x: clipX, y: clipY))
                isDrawing = false
            } else if p1.z <= -2.0 && p2.z > -2.0 {
                // Crossing from back to front: start at horizon
                let denominator = p2.z - p1.z
                let t = denominator != 0 ? (-2.0 - p1.z) / denominator : 0.5
                let clipX = p1.screen.x + t * (p2.screen.x - p1.screen.x)
                let clipY = p1.screen.y + t * (p2.screen.y - p1.screen.y)
                path.move(to: CGPoint(x: clipX, y: clipY))
                path.addLine(to: p2.screen)
                isDrawing = true
            } else {
                // Back hemisphere: occluded by solid sphere
                isDrawing = false
            }
        }

        // Base 3D surface stroke
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: size, lineCap: .round, lineJoin: .round)
        )

        // 3D Sculpt Specular Ridge Highlight
        if isSculpt {
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.65)),
                style: StrokeStyle(lineWidth: max(2.0, size * 0.35), lineCap: .round, lineJoin: .round)
            )
        }
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
