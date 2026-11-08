import Foundation

/// Switches for how far the island reaches into the window server.
///
/// Read from `UserDefaults` under Pod's own domain, so they can be flipped
/// without a settings UI:
///
/// ```
/// defaults write dev.yorha.pod UsePrivateWindowServerAPI -bool NO
/// defaults write dev.yorha.pod ShowIslandOnLockScreen -bool YES
/// defaults write dev.yorha.pod HideIslandInFullScreen -bool YES
/// ```
public struct IslandWindowing: Equatable, Sendable {
    /// Puts the panels in a private window-server Space above the lock screen
    /// (`IslandSpace`), and reads the active Space's kind. Undocumented API:
    /// fine for a locally distributed build, not for the App Store. Off, the
    /// island still sits above every app and beside full-screen ones, on
    /// public API alone, but cannot reach the lock screen.
    public var usesPrivateWindowServerAPI: Bool

    /// Keeps the island on the lock screen. Off by default: what is playing is
    /// not something to show to whoever walks past a locked machine. Needs the
    /// private Space.
    public var showsOnLockScreen: Bool

    /// Takes the island away while a full-screen app is in front. Off by
    /// default — the island stays reachable over full-screen apps. Needs the
    /// private API to tell a full-screen Space from a desktop.
    public var hidesInFullScreen: Bool

    public init(
        usesPrivateWindowServerAPI: Bool = true,
        showsOnLockScreen: Bool = false,
        hidesInFullScreen: Bool = false
    ) {
        self.usesPrivateWindowServerAPI = usesPrivateWindowServerAPI
        self.showsOnLockScreen = showsOnLockScreen
        self.hidesInFullScreen = hidesInFullScreen
    }

    public static let standard = IslandWindowing()

    public enum Key {
        public static let usesPrivateWindowServerAPI = "UsePrivateWindowServerAPI"
        public static let showsOnLockScreen = "ShowIslandOnLockScreen"
        public static let hidesInFullScreen = "HideIslandInFullScreen"
    }

    public init(defaults: UserDefaults) {
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }

        let standard = Self.standard
        self.init(
            usesPrivateWindowServerAPI: flag(Key.usesPrivateWindowServerAPI, standard.usesPrivateWindowServerAPI),
            showsOnLockScreen: flag(Key.showsOnLockScreen, standard.showsOnLockScreen),
            hidesInFullScreen: flag(Key.hidesInFullScreen, standard.hidesInFullScreen)
        )
    }
}

/// What the rest of the system is doing, as far as the island cares.
public struct SystemPresence: Equatable, Sendable {
    public var isScreenLocked: Bool
    /// False while another user's session is on screen (fast user switching).
    public var isSessionActive: Bool
    public var areScreensAsleep: Bool
    public var activeSpace: SpaceKind

    public init(
        isScreenLocked: Bool = false,
        isSessionActive: Bool = true,
        areScreensAsleep: Bool = false,
        activeSpace: SpaceKind = .desktop
    ) {
        self.isScreenLocked = isScreenLocked
        self.isSessionActive = isSessionActive
        self.areScreensAsleep = areScreensAsleep
        self.activeSpace = activeSpace
    }

    public static let normal = SystemPresence()
}

extension IslandWindowing {
    /// Whether the panels belong on screen at all.
    ///
    /// The island's own state decides what is drawn; this decides whether the
    /// system lets it be drawn. A hidden island with no resting target has
    /// nothing to put on screen either way.
    public func panelsBelongOnScreen(
        state: IslandState,
        hasRestingTarget: Bool,
        presence: SystemPresence
    ) -> Bool {
        guard state.isVisible || hasRestingTarget else { return false }
        guard presence.isSessionActive, !presence.areScreensAsleep else { return false }

        if presence.isScreenLocked, !(showsOnLockScreen && usesPrivateWindowServerAPI) {
            return false
        }

        if hidesInFullScreen, presence.activeSpace == .fullScreen {
            return false
        }

        return true
    }

    /// Whether the island may take the keyboard. Never on the lock screen,
    /// where the password field must keep it.
    public func allowsKeyFocus(presence: SystemPresence) -> Bool {
        !presence.isScreenLocked && presence.isSessionActive
    }
}
