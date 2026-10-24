import CoreGraphics

/// Pure geometry for the overlay button cluster: where it sits over a window,
/// the per-button hit rectangles, and the CoreGraphics→AppKit coordinate flip.
///
/// Everything is computed in **CoreGraphics global coordinates** (origin
/// top-left, +Y down — the space `CGWindowListCopyWindowInfo` bounds and
/// `CGEvent.location` use), and only `nsWindowFrame` flips into AppKit's
/// bottom-left space. Isolating the flip here — behind unit tests — keeps the
/// single most common bug in this kind of app (the Y inversion) out of the live
/// event path.
public struct OverlayGeometry: Equatable, Sendable {
    /// Diameter of one traffic-light button. Smaller than the macOS title-bar
    /// scaling would imply because Mission Control thumbnails are themselves
    /// shrunk — this keeps the cluster proportional and unobtrusive, matching
    /// native Mission Control.
    public static let buttonSize: CGFloat = 22
    public static let buttonSpacing: CGFloat = 4
    public static let clusterPadding: CGFloat = 6
    /// SF Symbol point size for the glyph centered in a button (scaled to the
    /// smaller button — held at half the diameter).
    public static let symbolSize: CGFloat = 11
    /// Horizontal inset of the first button from the window's left edge. The
    /// cluster is anchored at the top-left and straddles the *top* edge (see
    /// `clusterFrameCG`); this only controls the left gap.
    public static let edgeInset: CGFloat = 6
    /// How far the cluster hangs **above** the window's top edge — half a button
    /// (the row's vertical center sits on `minY`) plus the cluster padding. The
    /// live engine's hover acquisition uses this same value as its acquire band,
    /// so the band always matches the zone the cluster actually occupies.
    public static let topOverhang: CGFloat = buttonSize / 2 + clusterPadding

    /// The user's size multiplier; every metric below is the static base × this.
    /// `edgeInset` stays unscaled — it is a gap to the thumbnail edge, not part of
    /// the cluster.
    public let scale: CGFloat
    public var buttonSize: CGFloat { Self.buttonSize * scale }
    public var buttonSpacing: CGFloat { Self.buttonSpacing * scale }
    public var clusterPadding: CGFloat { Self.clusterPadding * scale }
    public var symbolSize: CGFloat { Self.symbolSize * scale }
    public var topOverhang: CGFloat { Self.topOverhang * scale }

    public let windowFrame: CGRect
    public let actionCount: Int
    /// Height of the primary (menu-bar) screen — the pivot for the CG↔AppKit
    /// Y flip. CG global coords pivot about this screen's top edge regardless of
    /// which display the window is on.
    public let pivotHeight: CGFloat

    public init(windowFrame: CGRect, actionCount: Int, pivotHeight: CGFloat, scale: CGFloat = 1) {
        self.windowFrame = windowFrame
        self.actionCount = max(0, actionCount)
        self.pivotHeight = pivotHeight
        self.scale = scale
    }

    public var clusterSize: CGSize {
        guard actionCount > 0 else { return .zero }
        let width = clusterPadding * 2
            + CGFloat(actionCount) * buttonSize
            + CGFloat(actionCount - 1) * buttonSpacing
        let height = clusterPadding * 2 + buttonSize
        return CGSize(width: width, height: height)
    }

    /// The cluster rect in CG coordinates, anchored to the window's top-left and
    /// **straddling the top edge**: the button row's vertical center sits exactly
    /// on `windowFrame.minY`, so each button is half inside the window and half
    /// above it — mirroring native Mission Control, where the title-bar controls
    /// hang off the thumbnail's top edge rather than floating fully inside. The first button's left edge sits `edgeInset` in from the window's
    /// left edge. (The `-clusterPadding` terms back the rect origin out past the
    /// SwiftUI padding so the *buttons*, not the padding, land on those anchors.)
    public var clusterFrameCG: CGRect {
        CGRect(
            x: windowFrame.minX + Self.edgeInset - clusterPadding,
            y: windowFrame.minY - topOverhang,
            width: clusterSize.width,
            height: clusterSize.height
        )
    }

    /// The cluster rect as an `NSWindow` frame (AppKit bottom-left global coords).
    public var nsWindowFrame: CGRect {
        let cg = clusterFrameCG
        return CGRect(x: cg.minX, y: pivotHeight - cg.maxY, width: cg.width, height: cg.height)
    }

    /// Hit rect for the button at `index`, in CG coordinates.
    public func buttonRectCG(_ index: Int) -> CGRect {
        let cluster = clusterFrameCG
        let x = cluster.minX + clusterPadding
            + CGFloat(index) * (buttonSize + buttonSpacing)
        let y = cluster.minY + clusterPadding
        return CGRect(x: x, y: y, width: buttonSize, height: buttonSize)
    }

    /// The button index hit by a CG-space point, or `nil` for a miss (outside the
    /// cluster). The WHOLE cluster is the live target, partitioned into
    /// `actionCount` equal vertical columns: the 6 pt padding bands and the 4 pt
    /// inter-button gaps become hit area instead of dead space, so each control's
    /// clickable region is its full column × the full 32 pt cluster height, rather
    /// than a tight 20×20 circle (~49 % coverage) with `nil` gaps between buttons.
    /// The visual 20 pt circles (`buttonRectCG`) are unchanged; only the hit
    /// mapping widens.
    public func hitTest(_ point: CGPoint) -> Int? {
        guard actionCount > 0 else { return nil }
        let cluster = clusterFrameCG
        guard cluster.contains(point) else { return nil }
        let columnWidth = cluster.width / CGFloat(actionCount)
        let column = Int((point.x - cluster.minX) / columnWidth)
        return min(max(column, 0), actionCount - 1)
    }
}
