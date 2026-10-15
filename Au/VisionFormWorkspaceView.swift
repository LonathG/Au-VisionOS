//
//  VisionFormWorkspaceView.swift
//  VisionForm 3D - Spatial Studio
//
//  Apple visionOS Spatial Computing 3D Modeling Interface
//

import SwiftUI
import RealityKit
import RealityKitContent

// MARK: - Brush Data Types
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

public struct BrushStroke: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var points: [CGPoint]
    public var color: Color
    public var size: CGFloat
    public var isSculpt: Bool

    public init(id: UUID = UUID(), points: [CGPoint], color: Color, size: CGFloat, isSculpt: Bool) {
        self.id = id
        self.points = points
        self.color = color
        self.size = size
        self.isSculpt = isSculpt
    }
}

public struct VisionFormWorkspaceView: View {
    // Spatial Tool & Material State
    @State private var activeTool: String = "Sculpt"
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

    // Interactive Brush State
    @State private var brushStrokes: [BrushStroke] = [
        BrushStroke(
            points: [
                CGPoint(x: 120, y: 155),
                CGPoint(x: 150, y: 165),
                CGPoint(x: 185, y: 168),
                CGPoint(x: 220, y: 160)
            ],
            color: .cyan,
            size: 14.0,
            isSculpt: false
        )
    ]
    @State private var activeStrokePoints: [CGPoint] = []
    @State private var activeStrokeColor: Color = .cyan
    @State private var activeStrokeSize: CGFloat = 14.0
    @State private var brushMode: BrushMode = .paint
    @State private var brushOrbitMode: Bool = false

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

    // Materials list matching Stitch specifications
    private let materials: [(name: String, color: Color, gradient: [Color])] = [
        ("Brushed Steel", Color(white: 0.7), [Color(white: 0.85), Color(white: 0.45)]),
        ("Organic Polymer", Color(red: 0.4, green: 0.65, blue: 1.0), [Color(red: 0.65, green: 0.78, blue: 1.0), Color(red: 0.24, green: 0.56, blue: 1.0)]),
        ("Carbon Fiber", Color(white: 0.2), [Color(white: 0.35), Color(white: 0.1)])
    ]

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

                    // 3D Viewport Centerpiece
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

                // Bottom Telemetry Tag
                HStack {
                    telemetryTag
                        .padding(.leading, 36)
                        .padding(.bottom, 24)
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

    // MARK: - Viewport Center 3D Model
    private var viewportCenter: some View {
        VStack(spacing: 12) {
            // Floating Brush HUD Palette if Brush or Sculpt tool is active
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
                    // Layer 3: Base Geometry Mesh Core
                    if isBaseMeshLayerVisible {
                        Model3D(named: "Scene", bundle: realityKitContentBundle) { model in
                            model
                                .resizable()
                                .scaledToFit()
                                .frame(width: 340, height: 340)
                                .opacity(layerOpacity["base"] ?? 1.0)
                        } placeholder: {
                            isometricPolyhedronView
                        }
                    }

                    // Layer 2: Topology Wireframe Grid
                    if isWireframeLayerVisible {
                        WireframeOverlayView(subdivisions: 10)
                            .frame(width: 340, height: 340)
                            .scaleEffect(isExplodedView ? 1.22 : 1.0)
                            .opacity(layerOpacity["wireframe"] ?? 0.85)
                            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExplodedView)
                    }

                    // Layer 1: Surface Paint & Sculpt Deformation Strokes
                    if isPaintLayerVisible {
                        BrushStrokesCanvasView(
                            strokes: brushStrokes,
                            activePoints: activeStrokePoints,
                            activeColor: activeStrokeColor,
                            activeSize: activeStrokeSize
                        )
                        .frame(width: 340, height: 340)
                        .scaleEffect(isExplodedView ? 1.12 : 1.0)
                        .opacity(layerOpacity["paint"] ?? 1.0)
                        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isExplodedView)
                    }
                }
                .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
                .contentShape(Circle())
                // Painting & Orbiting Gesture on the 3D Model
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let center = CGPoint(x: 170, y: 170)
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            let distFromCenter = sqrt(dx * dx + dy * dy)

                            if (activeTool == "Brush" || activeTool == "Sculpt") && !brushOrbitMode {
                                if distFromCenter <= 175 {
                                    if brushMode == .erase {
                                        brushStrokes.removeAll { stroke in
                                            stroke.points.contains { pt in
                                                hypot(pt.x - value.location.x, pt.y - value.location.y) < activeStrokeSize * 1.5
                                            }
                                        }
                                    } else {
                                        activeStrokePoints.append(value.location)
                                    }
                                } else {
                                    // Touch is outside sphere: rotate model
                                    rotationY += Double(value.translation.width) * 0.03
                                    rotationX -= Double(value.translation.height) * 0.03
                                }
                            } else {
                                // Default orbit gesture
                                rotationY += Double(value.translation.width) * 0.04
                                rotationX -= Double(value.translation.height) * 0.04
                            }
                        }
                        .onEnded { value in
                            if (activeTool == "Brush" || activeTool == "Sculpt") && !brushOrbitMode && !activeStrokePoints.isEmpty {
                                let stroke = BrushStroke(
                                    points: activeStrokePoints,
                                    color: activeStrokeColor,
                                    size: activeStrokeSize,
                                    isSculpt: brushMode == .sculpt
                                )
                                brushStrokes.append(stroke)
                                activeStrokePoints = []
                                polyCount += (brushMode == .sculpt ? 320 : 84)
                            }
                        }
                )
            }
        }
        .frame(maxWidth: 500, maxHeight: 560)
    }

    // MARK: - Brush Control HUD Palette
    private var brushControlHUD: some View {
        HStack(spacing: 12) {
            // Mode Selector: Paint vs Sculpt vs Erase
            HStack(spacing: 3) {
                ForEach(BrushMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            brushMode = mode
                            if mode == .sculpt { activeTool = "Sculpt" }
                            else if mode == .paint { activeTool = "Brush" }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 11))
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            brushMode == mode ? Color.cyan.opacity(0.3) : Color.clear
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(brushMode == mode ? .white : .white.opacity(0.65))
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())

            Divider().frame(height: 18).background(Color.white.opacity(0.2))

            // Color Swatches
            HStack(spacing: 6) {
                ForEach([Color.cyan, Color(red: 1.0, green: 0.2, blue: 0.6), Color(red: 1.0, green: 0.8, blue: 0.1), Color(red: 0.2, green: 0.9, blue: 0.4), Color.white], id: \.self) { color in
                    Button {
                        activeStrokeColor = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: activeStrokeColor == color ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().frame(height: 18).background(Color.white.opacity(0.2))

            // Brush Size Pills
            HStack(spacing: 4) {
                ForEach([8, 14, 22], id: \.self) { size in
                    Button {
                        activeStrokeSize = CGFloat(size)
                    } label: {
                        Text("\(size)px")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(activeStrokeSize == CGFloat(size) ? Color.blue.opacity(0.4) : Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
            }

            Divider().frame(height: 18).background(Color.white.opacity(0.2))

            // Draw vs Orbit Toggle Button
            Button {
                brushOrbitMode.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: brushOrbitMode ? "arrow.triangle.2.circlepath" : "hand.draw.fill")
                        .font(.system(size: 11))
                    Text(brushOrbitMode ? "Orbit" : "Paint")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(brushOrbitMode ? Color.purple.opacity(0.35) : Color.blue.opacity(0.35))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)

            // Clear All Strokes Button
            if !brushStrokes.isEmpty {
                Button {
                    withAnimation {
                        brushStrokes.removeAll()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Clear Strokes")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .darkBlueTranslucentCapsule()
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
                    title: "Surface Paint",
                    subtitle: "\(brushStrokes.count) brush strokes",
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
                    subtitle: "Organic Polymer Solid",
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
                        brushStrokes.append(
                            BrushStroke(
                                points: [CGPoint(x: 120, y: 140), CGPoint(x: 170, y: 170), CGPoint(x: 220, y: 150)],
                                color: activeStrokeColor,
                                size: activeStrokeSize,
                                isSculpt: false
                            )
                        )
                    }
                } label: {
                    Label("Add Stroke", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    withAnimation {
                        isPaintLayerVisible = true
                        isWireframeLayerVisible = true
                        isBaseMeshLayerVisible = true
                        isGizmoLayerVisible = true
                    }
                } label: {
                    Text("Show All")
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

    // Fallback Isometric Polyhedron Graphic if 3D bundle asset is loading
    private var isometricPolyhedronView: some View {
        ZStack {
            Image(systemName: "cube.transparent")
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6), Color.indigo.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .cyan.opacity(0.3), radius: 30)

            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .offset(x: 0, y: -90)
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
                .offset(x: 80, y: 30)
            Circle()
                .fill(Color.cyan)
                .frame(width: 8, height: 8)
                .offset(x: -80, y: 30)
        }
    }

    // MARK: - Telemetry Tag
    private var telemetryTag: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(activeTool == "Brush" ? Color.cyan : Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: activeTool == "Brush" ? .cyan : .green, radius: 4)

            Text(
                activeTool == "Brush"
                    ? "Tool: Brush (\(brushMode.rawValue)) | Strokes: \(brushStrokes.count) | Size: \(Int(activeStrokeSize))px"
                    : (activeTool == "Layers" || showLayersPanel
                        ? "Tool: Layers | Mode: \(isExplodedView ? "Exploded 3D" : "Unified") | Active Layers: 4"
                        : "Poly Count: \(polyCount.formatted()) | Scale: 1:1 | X,Y,Z: (\(Int(rotationX)), \(Int(rotationY)), 300)")
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
                let isActive = activeTool == tool.name || (tool.name == "Layers" && showLayersPanel)
                Button {
                    activeTool = tool.name
                    if tool.name == "Layers" || tool.name == "Boolean" {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showLayersPanel.toggle()
                        }
                    } else if tool.name == "Brush" {
                        brushMode = .paint
                        brushOrbitMode = false
                    } else if tool.name == "Sculpt" {
                        brushMode = .sculpt
                        brushOrbitMode = false
                    }
                } label: {
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
                }
                .buttonStyle(.plain)
                .help(tool.name)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .darkBlueTranslucentRounded(cornerRadius: 28)
    }

    // MARK: - Right Inspector Card
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

            // Material Sphere Swatches
            VStack(alignment: .leading, spacing: 10) {
                Text("ACTIVE MATERIAL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                HStack(spacing: 12) {
                    ForEach(materials, id: \.name) { mat in
                        let isSelected = activeMaterial == mat.name
                        Button {
                            activeMaterial = mat.name
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
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? Color.blue.opacity(0.5) : .black.opacity(0.3), radius: 8)

                                Text(mat.name)
                                    .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .blue : .white.opacity(0.7))
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
                                    .stroke(isSelected ? Color.blue.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Precision Sliders
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
                    // Undo last brush stroke
                    if !brushStrokes.isEmpty {
                        withAnimation {
                            _ = brushStrokes.removeLast()
                        }
                    }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .disabled(brushStrokes.isEmpty)

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

// MARK: - Topology Wireframe Overlay View
public struct WireframeOverlayView: View {
    var subdivisions: Int = 10

    public init(subdivisions: Int = 10) {
        self.subdivisions = subdivisions
    }

    public var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Outer glowing rim
            context.stroke(
                Circle().path(in: CGRect(origin: .zero, size: size)),
                with: .color(Color.cyan.opacity(0.55)),
                lineWidth: 1.5
            )

            // Latitude rings
            for i in 1..<subdivisions {
                let norm = Double(i) / Double(subdivisions)
                let angle = norm * .pi
                let yOffset = cos(angle) * (h / 2)
                let ringWidth = sin(angle) * w
                let ringHeight = max(2, ringWidth * 0.28)
                let rect = CGRect(
                    x: (w - ringWidth) / 2,
                    y: (h / 2) + yOffset - (ringHeight / 2),
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
                let ringWidth = max(2, sin(angle) * w)
                let rect = CGRect(
                    x: (w - ringWidth) / 2,
                    y: 0,
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

// MARK: - Interactive Brush Strokes Canvas View
public struct BrushStrokesCanvasView: View {
    var strokes: [BrushStroke]
    var activePoints: [CGPoint]
    var activeColor: Color
    var activeSize: CGFloat

    public init(strokes: [BrushStroke], activePoints: [CGPoint], activeColor: Color, activeSize: CGFloat) {
        self.strokes = strokes
        self.activePoints = activePoints
        self.activeColor = activeColor
        self.activeSize = activeSize
    }

    public var body: some View {
        Canvas { context, size in
            // Draw all finalized strokes
            for stroke in strokes {
                guard !stroke.points.isEmpty else { continue }

                if stroke.points.count == 1 {
                    let pt = stroke.points[0]
                    let rect = CGRect(
                        x: pt.x - stroke.size / 2,
                        y: pt.y - stroke.size / 2,
                        width: stroke.size,
                        height: stroke.size
                    )
                    context.fill(Circle().path(in: rect), with: .color(stroke.color))
                    if stroke.isSculpt {
                        let hlRect = CGRect(x: pt.x - stroke.size / 4, y: pt.y - stroke.size / 4, width: stroke.size / 2, height: stroke.size / 2)
                        context.fill(Circle().path(in: hlRect), with: .color(.white.opacity(0.85)))
                    }
                } else {
                    var path = Path()
                    path.move(to: stroke.points[0])
                    for pt in stroke.points.dropFirst() {
                        path.addLine(to: pt)
                    }

                    // Stroke base
                    context.stroke(
                        path,
                        with: .color(stroke.color),
                        style: StrokeStyle(lineWidth: stroke.size, lineCap: .round, lineJoin: .round)
                    )

                    // 3D Sculpt Specular Ridge Highlight
                    if stroke.isSculpt {
                        context.stroke(
                            path,
                            with: .color(.white.opacity(0.65)),
                            style: StrokeStyle(lineWidth: max(2, stroke.size * 0.35), lineCap: .round, lineJoin: .round)
                        )
                    }
                }
            }

            // Draw active in-progress stroke
            if !activePoints.isEmpty {
                if activePoints.count == 1 {
                    let pt = activePoints[0]
                    let rect = CGRect(
                        x: pt.x - activeSize / 2,
                        y: pt.y - activeSize / 2,
                        width: activeSize,
                        height: activeSize
                    )
                    context.fill(Circle().path(in: rect), with: .color(activeColor))
                } else {
                    var path = Path()
                    path.move(to: activePoints[0])
                    for pt in activePoints.dropFirst() {
                        path.addLine(to: pt)
                    }
                    context.stroke(
                        path,
                        with: .color(activeColor),
                        style: StrokeStyle(lineWidth: activeSize, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .clipShape(Circle())
        .shadow(color: activeColor.opacity(0.35), radius: 6)
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
