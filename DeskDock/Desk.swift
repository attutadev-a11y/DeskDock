import UIKit

/// Shared hub that connects the phone scene (trackpad + keyboard) to the
/// external-display scene (the desktop). Both scenes live in the same process,
/// so they can talk to each other directly on the main thread.
final class Desk {
    static let shared = Desk()
    private init() {}

    weak var desktop: DesktopViewController? {
        didSet { phone?.refreshConnectionState() }
    }
    weak var phone: TrackpadViewController?
}
