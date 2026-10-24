import CloseUpKit
import SwiftUI

/// Per-session hover state for the overlay cluster. The overlay window ignores
/// mouse events (it is passive — the event tap handles clicks), so SwiftUI hover
/// cannot fire; the engine's mouse-tracking loop sets `hoveredIndex` instead.
@MainActor
@Observable
final class OverlayHoverState {
    var hoveredIndex: Int?
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

    var body: some View {
        HStack(spacing: geometry.buttonSpacing) {
            ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                OverlayButtonView(
                    action: action,
                    geometry: geometry,
                    isHovered: hoverState.hoveredIndex == index
                )
            }
        }
        .padding(geometry.clusterPadding)
        .environment(\.locale, locale)
        .fixedSize()
    }
}

private struct OverlayButtonView: View {
    let action: WindowAction
    let geometry: OverlayGeometry
    let isHovered: Bool

    var body: some View {
        ZStack {
            Circle().fill(DS.Palette.overlayButtonFill)
            Image(systemName: action.symbolName)
                .font(.system(size: geometry.symbolSize, weight: .bold))
                .foregroundStyle(DS.Palette.overlayButtonSymbol)
        }
        .frame(width: geometry.buttonSize, height: geometry.buttonSize)
        .overlay(Circle().strokeBorder(DS.Palette.overlayButtonBorder, lineWidth: DS.Overlay.buttonBorderWidth))
        .shadow(color: DS.Palette.overlayButtonShadow, radius: DS.Overlay.buttonShadowRadius, y: DS.Overlay.buttonShadowYOffset)
        .scaleEffect(isHovered ? DS.Overlay.hoverLift : 1.0)
        .animation(DS.Motion.overlay, value: isHovered)
        .help(LocalizedStringKey(action.titleKey))
    }
}
