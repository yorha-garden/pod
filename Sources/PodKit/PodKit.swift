/// Pod's behaviour lives here rather than in the executable, so the test
/// target can reach it. Anything with a decision in it — geometry, timing,
/// style resolution, what gets announced — belongs in this module behind a
/// pure interface; the executable only wires it to a window.
public enum Pod {
    public static let version = "0.1.0"
}
