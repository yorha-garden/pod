import AppKit

// Private window-server calls. They are exported from CoreGraphics (the
// SkyLight re-exports), undocumented, and not allowed on the App Store — Pod
// is distributed locally and ad-hoc signed, and everything below sits behind
// `IslandWindowing.usesPrivateWindowServerAPI`, so turning that off leaves
// Pod on public API alone.

private typealias CGSConnectionID = Int32
private typealias CGSSpaceID = UInt64

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSSpaceCreate")
private func CGSSpaceCreate(_ cid: CGSConnectionID, _ flag: Int32, _ options: CFDictionary?) -> CGSSpaceID

@_silgen_name("CGSSpaceDestroy")
private func CGSSpaceDestroy(_ cid: CGSConnectionID, _ space: CGSSpaceID)

@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func CGSSpaceSetAbsoluteLevel(_ cid: CGSConnectionID, _ space: CGSSpaceID, _ level: Int32)

@_silgen_name("CGSShowSpaces")
private func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: CFArray)

@_silgen_name("CGSHideSpaces")
private func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: CFArray)

@_silgen_name("CGSAddWindowsToSpaces")
private func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray)

@_silgen_name("CGSRemoveWindowsFromSpaces")
private func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray)

@_silgen_name("CGSGetActiveSpace")
private func CGSGetActiveSpace(_ cid: CGSConnectionID) -> CGSSpaceID

@_silgen_name("CGSSpaceGetType")
private func CGSSpaceGetType(_ cid: CGSConnectionID, _ space: CGSSpaceID) -> Int32

/// What kind of Space the user is looking at.
public enum SpaceKind: Equatable, Sendable {
    case desktop
    case fullScreen
    case other(Int32)

    /// The window server's own numbering: 0 is an ordinary desktop, 4 a Space
    /// made by an app going full screen.
    public init(windowServerType type: Int32) {
        switch type {
        case 0: self = .desktop
        case 4: self = .fullScreen
        default: self = .other(type)
        }
    }
}

/// A Space of Pod's own, above the lock screen, that the island's panels live
/// in.
///
/// Window levels order windows within a Space; Spaces themselves are ordered
/// by an absolute level of their own. Full-screen apps and the lock screen are
/// Spaces, so no window level alone keeps an overlay above them. A Space at
/// absolute level 400 — the lock screen's is 300 — does, and the panels in it
/// stay put on every desktop because the Space is shown everywhere at once.
@MainActor
public final class IslandSpace {
    /// One above the screen-lock Space.
    public static let absoluteLevel: Int32 = 400

    private let connection: CGSConnectionID
    private let space: CGSSpaceID
    private var members: Set<Int> = []

    public init() {
        connection = CGSMainConnectionID()
        // Flag 1: a Space the window server shows rather than one the user
        // switches to.
        space = CGSSpaceCreate(connection, 1, nil)
        CGSSpaceSetAbsoluteLevel(connection, space, Self.absoluteLevel)
        CGSShowSpaces(connection, [NSNumber(value: space)] as CFArray)
    }

    /// Moves windows into the Space. A window is only given a window-server
    /// number once it has been ordered in, so call this after showing it;
    /// windows without one are skipped.
    ///
    /// Repeat it after every `orderFront`: ordering a window in puts it back
    /// on the Space in front, so membership does not survive a re-order.
    public func add(_ windows: [NSWindow]) {
        let numbers = windows.map(\.windowNumber).filter { $0 > 0 }
        guard !numbers.isEmpty else { return }

        CGSAddWindowsToSpaces(connection, numbers as CFArray, [NSNumber(value: space)] as CFArray)
        members.formUnion(numbers)
    }

    public func remove(_ windows: [NSWindow]) {
        let numbers = windows.map(\.windowNumber).filter { members.contains($0) }
        guard !numbers.isEmpty else { return }

        CGSRemoveWindowsFromSpaces(connection, numbers as CFArray, [NSNumber(value: space)] as CFArray)
        members.subtract(numbers)
    }

    /// Hides and destroys the Space. The windows in it fall back to the
    /// ordinary Spaces their collection behaviour puts them on.
    public func tearDown() {
        if !members.isEmpty {
            CGSRemoveWindowsFromSpaces(
                connection,
                Array(members) as CFArray,
                [NSNumber(value: space)] as CFArray
            )
            members.removeAll()
        }
        let spaces = [NSNumber(value: space)] as CFArray
        CGSHideSpaces(connection, spaces)
        CGSSpaceDestroy(connection, space)
    }

    /// The kind of Space currently on screen, read from the window server.
    public static func activeSpaceKind() -> SpaceKind {
        let connection = CGSMainConnectionID()
        return SpaceKind(windowServerType: CGSSpaceGetType(connection, CGSGetActiveSpace(connection)))
    }
}
