import AppKit
import Foundation

/// The system accessibility settings Pod honours.
///
/// Modelled as a value type so every consumer can be exercised in tests
/// without a live `NSWorkspace` or a screen.
public struct AccessibilityPreferences: Equatable, Sendable {
    public var reduceMotion: Bool
    public var reduceTransparency: Bool
    public var increaseContrast: Bool
    public var differentiateWithoutColor: Bool
    public var screenReaderActive: Bool
    public var fullKeyboardAccess: Bool

    public init(
        reduceMotion: Bool = false,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        differentiateWithoutColor: Bool = false,
        screenReaderActive: Bool = false,
        fullKeyboardAccess: Bool = false
    ) {
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.differentiateWithoutColor = differentiateWithoutColor
        self.screenReaderActive = screenReaderActive
        self.fullKeyboardAccess = fullKeyboardAccess
    }

    /// Nothing switched on: a pointer user with default settings.
    public static let standard = AccessibilityPreferences()

    /// True when the user is likely not driving Pod with a pointer and an
    /// unimpeded look at the screen. Only ever used to give them *more* time.
    public var impliesAssistiveUse: Bool {
        screenReaderActive || fullKeyboardAccess
    }
}

/// Keeps `AccessibilityPreferences` in step with the system.
///
/// macOS posts one notification for the display options and separate ones for
/// application launches, so both are observed: the first covers Reduce Motion
/// and friends, the second covers a screen reader starting after Pod did.
@MainActor
public final class AccessibilityPreferencesObserver: ObservableObject {
    @Published public private(set) var preferences: AccessibilityPreferences

    private let workspace: NSWorkspace
    private var tokens: [NSObjectProtocol] = []

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        self.preferences = Self.read(from: workspace)
        subscribe()
    }

    deinit {
        let center = workspace.notificationCenter
        for token in tokens {
            center.removeObserver(token)
        }
    }

    /// Re-read the system settings. Exposed so the controller can refresh on
    /// presentation, which catches anything a missing notification dropped.
    public func refresh() {
        let latest = Self.read(from: workspace)
        if latest != preferences {
            preferences = latest
        }
    }

    private func subscribe() {
        let center = workspace.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]
        tokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
        }
    }

    private static func read(from workspace: NSWorkspace) -> AccessibilityPreferences {
        AccessibilityPreferences(
            reduceMotion: workspace.accessibilityDisplayShouldReduceMotion,
            reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
            differentiateWithoutColor: workspace.accessibilityDisplayShouldDifferentiateWithoutColor,
            screenReaderActive: isScreenReaderRunning(workspace),
            fullKeyboardAccess: NSApplication.shared.isFullKeyboardAccessEnabled
        )
    }

    /// VoiceOver exposes no public "is it running" flag on macOS, so its
    /// process is the available signal. The check is deliberately fail-safe:
    /// a false negative only returns Pod to the default timing, and the
    /// "never dismiss" preference still pins the island open regardless.
    static func isScreenReaderRunning(_ workspace: NSWorkspace) -> Bool {
        workspace.runningApplications.contains { $0.bundleIdentifier == "com.apple.VoiceOver" }
    }
}
