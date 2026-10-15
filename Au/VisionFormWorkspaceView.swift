//
//  VisionFormWorkspaceView.swift
//  VisionForm 3D - Spatial Studio
//
//  Apple visionOS Spatial Computing 3D Modeling Interface
//

import SwiftUI
import RealityKit
import RealityKitContent

public struct VisionFormWorkspaceView: View {
    // Spatial State
    @State private var activeTool: String = "Sculpt"
    @State private var activeMaterial: String = "Organic Polymer"
    @State private var roughness: Double = 43.0
    @State private var metallic: Double = 10.5
    @State private var specular: Double = 1.5
    @State private var isGizmoActive: Bool = true
    @State private var showInspector: Bool = true
    @State private var showAIGenSheet: Bool = false
    @State private var rotationX: Double = -2.0
    @State private var rotationY: Double = -2.0
    @State private var polyCount: Int = 42804

    // Tools list matching Stitch specifications
    private let tools: [(name: String, icon: String)] = [
        ("Extrude", "square.stack.3d.up"),
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
            // Full-bleed dark slate workspace background (#0D1117)
            Color(red: 13/255, green: 17/255, blue: 23/255)
                .ignoresSafeArea()

            // Subtle depth shadows & radial ambient lighting
            RadialGradient(
                colors: [Color.blue.opacity(0.12), Color.cyan.opacity(0.04), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 650
            )
            .ignoresSafeArea()

            // Structured Studio Layout (Top Bar, Studio Workspace, Bottom Telemetry)
            VStack(spacing: 0) {
                // Top Navigation Bar
                topBar
                    .padding(.top, 20)
                    .padding(.horizontal, 32)

                // Middle Studio Row (Left Sidebar, Centered 3D Viewport, Right Inspector)
                HStack(alignment: .center, spacing: 16) {
                    // Left Vertical Toolbar - safely inset with 32pt padding
                    leftToolbar
                        .padding(.leading, 32)

                    Spacer(minLength: 20)

                    // 3D Viewport Centerpiece
                    viewportCenter

                    Spacer(minLength: 20)

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
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue.opacity(0.3))
    }

    // MARK: - Viewport Center 3D Model
    private var viewportCenter: some View {
        ZStack {
            // Floor shadow & ambient occlusion glow
            Ellipse()
                .fill(Color.black.opacity(0.75))
                .frame(width: 320, height: 60)
                .blur(radius: 20)
                .offset(y: 180)

            // Spatial Ring Gizmo
            if isGizmoActive {
                Circle()
                    .strokeBorder(Color.blue.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .frame(width: 360, height: 360)
                Circle()
                    .strokeBorder(Color.cyan.opacity(0.15), lineWidth: 1)
                    .frame(width: 440, height: 440)
            }

            // Centered Isometric Mesh Preview Object
            Model3D(named: "Scene", bundle: realityKitContentBundle) { model in
                model
                    .resizable()
                    .scaledToFit()
                    .frame(width: 340, height: 340)
            } placeholder: {
                isometricPolyhedronView
            }
            .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        rotationY += Double(value.translation.width) * 0.04
                        rotationX -= Double(value.translation.height) * 0.04
                    }
            )
        }
        .frame(maxWidth: 500, maxHeight: 500)
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
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: .green, radius: 4)

            Text("Poly Count: \(polyCount.formatted()) | Scale: 1:1 | X,Y,Z: (\(Int(rotationX)), \(Int(rotationY)), 300)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
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
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Left Vertical Toolbar
    private var leftToolbar: some View {
        VStack(spacing: 12) {
            ForEach(tools, id: \.name) { tool in
                let isActive = activeTool == tool.name
                Button {
                    activeTool = tool.name
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 18))
                            .foregroundColor(isActive ? .blue : .white.opacity(0.75))
                    }
                    .frame(width: 44, height: 44)
                    .background(
                        isActive
                            ? Color.blue.opacity(0.25)
                            : Color.white.opacity(0.04)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isActive ? Color.blue.opacity(0.5) : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: isActive ? Color.blue.opacity(0.3) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
                .help(tool.name)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
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
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 290)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 30, x: 0, y: 16)
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
                    // Undo
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())

                Button {
                    // Redo
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
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 20, y: 8)

            // Three subtle pagination dots below the pill
            HStack(spacing: 6) {
                Circle().fill(Color.white).frame(width: 5, height: 5)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 5, height: 5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(Capsule())
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
        .background(.ultraThinMaterial)
    }
}

#Preview(windowStyle: .automatic) {
    VisionFormWorkspaceView()
        .environment(AppModel())
}
