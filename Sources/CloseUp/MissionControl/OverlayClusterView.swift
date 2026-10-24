import CloseUpKit
import SwiftUI

/// Per-session hover state for the overlay cluster. The overlay window ignores
/// mouse events (it is passive — the event tap handles clicks), so SwiftUI hover
/// cannot fire; the engine's mouse-tracking loop sets `hoveredIndex` instead.
@MainActor
@Observable
final class OverlayHoverState {
    var hoveredIndex: Int?
    /// The window whose cluster is the interactive one. Always-show clusters (one
    /// persistent window per thumbnail) dim/brighten by comparing against this
    /// instead of being rebuilt, so a hover change animates instead of re-ordering windows.
    var hoveredWindowID: CGWindowID?
}

/// The visual button cluster drawn over the hovered Mission Control thumbnail.
/// Neutral gray-white circles (not the vivid stoplight colors) with no
/// surrounding box, matching native Mission Control. The
/// glyph is always shown — with monochrome buttons it is the only thing that
/// distinguishes close / minimize / zoom — and the hovered button lifts slightly.
/// Clicks are detected by the engine's EventTap against OverlayGeometry, never by
/// these views.
struct OverlayClusterView: View {
    let actions: [WindowAction]
    let geometry: OverlayGeometry
    let locale: Locale
    let hoverState: OverlayHoverState
    /// Set for an always-show cluster, which stays dim until `hoverState.hoveredWindowID`
    /// is its window; nil for the separate interactive overlay (always bright).
    var windowID: CGWindowID?
    var style: OverlayButtonStyle = .standard
    /// Fade/scale in on first render. Only for a cluster appearing where none was
    /// showing — a replacement window must not re-fade (the forced re-anchors would flicker).
    var animateIn = false
    @State private var appeared = false

    private var isHoveredWindow: Bool { windowID == nil || hoverState.hoveredWindowID == windowID }

    var body: some View {
        HStack(spacing: geometry.buttonSpacing) {
            ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                OverlayButtonView(
                    action: action,
                    geometry: geometry,
                    style: style,
                    isHovered: isHoveredWindow && hoverState.hoveredIndex == index
                )
            }
        }
        .padding(geometry.clusterPadding)
        .environment(\.locale, locale)
        .fixedSize()
        .opacity(isHoveredWindow ? 1 : DS.Overlay.dimmedOpacity)
        .animation(DS.Motion.overlay, value: isHoveredWindow)
        .scaleEffect(animateIn && !appeared ? DS.Overlay.appearScale : 1)
        .opacity(animateIn && !appeared ? 0 : 1)
        .onAppear { withAnimation(DS.Motion.overlayAppear) { appeared = true } }
    }
}

private struct OverlayButtonView: View {
    let action: WindowAction
    let geometry: OverlayGeometry
    let style: OverlayButtonStyle
    let isHovered: Bool

    var body: some View {
        face
            .frame(width: geometry.buttonSize, height: geometry.buttonSize)
            .scaleEffect(isHovered ? DS.Overlay.hoverLift : 1.0)
            .animation(DS.Motion.overlay, value: isHovered)
            .help(LocalizedStringKey(action.titleKey))
    }

    private var glyph: some View {
        Image(systemName: action.symbolName)
            .font(.system(size: geometry.symbolSize, weight: .bold))
    }

    @ViewBuilder
    private var face: some View {
        if style == .glass {
            glassFace
        } else {
            ZStack {
                Circle().fill(DS.Palette.overlayButtonFill)
                glyph.foregroundStyle(DS.Palette.overlayButtonSymbol)
            }
            .overlay(Circle().strokeBorder(DS.Palette.overlayButtonBorder, lineWidth: DS.Overlay.buttonBorderWidth))
            .shadow(color: DS.Palette.overlayButtonShadow, radius: DS.Overlay.buttonShadowRadius, y: DS.Overlay.buttonShadowYOffset)
        }
    }

    /// A glass look built from a blur material, forced `.active` (see `GlassBlur`:
    /// the overlay window is never key, so SwiftUI materials show the opaque inactive look). Not SwiftUI's `.glassEffect`: it
    /// replays its materialize animation in every fresh overlay window and settles
    /// near-invisible over Mission Control, so the forced re-anchors flickered.
    private var glassFace: some View {
        glyph.foregroundStyle(.primary)
            .frame(width: geometry.buttonSize, height: geometry.buttonSize)
            .background(GlassBlur().clipShape(Circle()))
            .overlay(Circle().strokeBorder(DS.Palette.overlayButtonBorder, lineWidth: DS.Overlay.buttonBorderWidth))
            .shadow(color: DS.Palette.overlayButtonShadow, radius: DS.Overlay.buttonShadowRadius, y: DS.Overlay.buttonShadowYOffset)
    }
}

/// Always-active behind-window blur; `NSVisualEffectView.state = .active` keeps it translucent in a never-key window.
private struct GlassBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.state = .active
        v.blendingMode = .behindWindow
        v.material = DS.Overlay.glassMaterial
        v.isEmphasized = false
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}
