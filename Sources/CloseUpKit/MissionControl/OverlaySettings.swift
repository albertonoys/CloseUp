import Foundation

/// Which overlay controls are shown, persisted as a single JSON blob. Defaults
/// = close + minimize + maximize all on; hide/quit are keyboard-only and never
/// appear as overlay buttons.
///
/// Forward/backward-compatible: every field decodes present-or-default, so a blob
/// written by an older build (missing a later toggle) still loads, and a blob
/// from a newer build (extra keys) loads on the fields this build knows. Each
/// default reproduces the pre-field behavior.
public struct OverlaySettings: Codable, Equatable, Sendable {
    public var showClose: Bool
    public var showMinimize: Bool
    public var showZoom: Bool
    /// Show the controls on every window at once, not only the hovered one.
    public var alwaysShow: Bool
    /// Multiplier on the traffic-light size (1 = the native-matching default).
    public var buttonScale: Double
    /// Center a lone control on the window's top-left corner instead of inset
    /// along the top edge.
    public var singleControlAtCorner: Bool

    /// The size steps offered in Settings.
    public static let buttonScaleRange: ClosedRange<Double> = 0.75...2.5

    public init(
        showClose: Bool = true,
        showMinimize: Bool = true,
        showZoom: Bool = true,
        alwaysShow: Bool = false,
        buttonScale: Double = 1,
        singleControlAtCorner: Bool = false
    ) {
        self.showClose = showClose
        self.showMinimize = showMinimize
        self.showZoom = showZoom
        self.alwaysShow = alwaysShow
        self.buttonScale = buttonScale
        self.singleControlAtCorner = singleControlAtCorner
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = OverlaySettings()
        showClose = try c.decodeIfPresent(Bool.self, forKey: .showClose) ?? d.showClose
        showMinimize = try c.decodeIfPresent(Bool.self, forKey: .showMinimize) ?? d.showMinimize
        showZoom = try c.decodeIfPresent(Bool.self, forKey: .showZoom) ?? d.showZoom
        alwaysShow = try c.decodeIfPresent(Bool.self, forKey: .alwaysShow) ?? d.alwaysShow
        let scale = try c.decodeIfPresent(Double.self, forKey: .buttonScale) ?? d.buttonScale
        buttonScale = min(max(scale, Self.buttonScaleRange.lowerBound), Self.buttonScaleRange.upperBound)
        singleControlAtCorner = try c.decodeIfPresent(Bool.self, forKey: .singleControlAtCorner) ?? d.singleControlAtCorner
    }

    /// Whether a given action's button is enabled. Hide/quit are keyboard-only
    /// and never appear as overlay buttons, so they are always disabled here.
    public func isEnabled(_ action: WindowAction) -> Bool {
        switch action {
        case .close: showClose
        case .minimize: showMinimize
        case .zoom: showZoom
        case .hide, .quit: false
        }
    }

    /// The enabled actions in left-to-right overlay order. Always non-empty in
    /// practice (the settings UI keeps at least close on), but callers must
    /// tolerate an empty result — an empty overlay simply doesn't show.
    public var enabledActions: [WindowAction] {
        WindowAction.allCases.filter(isEnabled)
    }
}
