import UIKit

class PhoneSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let vc = TrackpadViewController()
        window.rootViewController = vc
        self.window = window
        window.makeKeyAndVisible()
        Desk.shared.phone = vc
    }
}

/// The phone screen while a monitor is connected: a big trackpad, a keyboard
/// capture bar, and shortcut buttons to open desktop apps.
final class TrackpadViewController: UIViewController, UITextFieldDelegate {

    private let statusLabel = UILabel()
    private let appBar = UIStackView()
    private let keyBar = UIView()
    private let keyIcon = UILabel()
    private let keyField = UITextField()
    private let trackpad = UIView()
    private let hintLabel = UILabel()
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private var lastPressPoint = CGPoint.zero
    private let sentinel = "\u{200B}" // zero-width space so backspace is detectable

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.07, alpha: 1)

        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        view.addSubview(statusLabel)

        appBar.axis = .horizontal
        appBar.distribution = .fillEqually
        appBar.spacing = 10
        for kind in DeskAppKind.allCases {
            let b = UIButton(type: .system)
            b.setTitle(kind.rawValue, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            b.backgroundColor = UIColor(white: 0.16, alpha: 1)
            b.setTitleColor(.white, for: .normal)
            b.layer.cornerRadius = 10
            b.tag = kind.tag
            b.addTarget(self, action: #selector(openApp(_:)), for: .touchUpInside)
            appBar.addArrangedSubview(b)
        }
        view.addSubview(appBar)

        keyBar.backgroundColor = UIColor(white: 0.16, alpha: 1)
        keyBar.layer.cornerRadius = 10
        keyIcon.text = "⌨️"
        keyIcon.font = .systemFont(ofSize: 18)
        keyField.delegate = self
        keyField.text = sentinel
        keyField.tintColor = .clear
        keyField.textColor = UIColor(white: 0.16, alpha: 1)
        keyField.autocorrectionType = .no
        keyField.autocapitalizationType = .none
        keyField.smartQuotesType = .no
        keyField.smartDashesType = .no
        keyField.smartInsertDeleteType = .no
        keyField.spellCheckingType = .no
        keyField.returnKeyType = .default
        let keyHint = UILabel()
        keyHint.text = "Tap here, then type — keys go to the monitor"
        keyHint.font = .systemFont(ofSize: 13)
        keyHint.textColor = UIColor(white: 0.6, alpha: 1)
        keyHint.tag = 99
        keyBar.addSubview(keyIcon)
        keyBar.addSubview(keyField)
        keyBar.addSubview(keyHint)
        keyBar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focusKeyboard)))
        view.addSubview(keyBar)

        trackpad.backgroundColor = UIColor(white: 0.12, alpha: 1)
        trackpad.layer.cornerRadius = 16
        view.addSubview(trackpad)

        hintLabel.text = "1 finger: move  ·  tap: click\nlong-press + move: drag window  ·  2 fingers: scroll"
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = UIColor(white: 0.45, alpha: 1)
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center
        trackpad.addSubview(hintLabel)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 1
        trackpad.addGestureRecognizer(pan)

        let scroll = UIPanGestureRecognizer(target: self, action: #selector(onScroll(_:)))
        scroll.minimumNumberOfTouches = 2
        scroll.maximumNumberOfTouches = 2
        trackpad.addGestureRecognizer(scroll)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        trackpad.addGestureRecognizer(tap)

        let press = UILongPressGestureRecognizer(target: self, action: #selector(onPress(_:)))
        press.minimumPressDuration = 0.3
        trackpad.addGestureRecognizer(press)

        refreshConnectionState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The desktop dies if the phone locks, so keep the screen awake.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safe = view.safeAreaInsets
        let w = view.bounds.width - 32
        statusLabel.frame = CGRect(x: 16, y: safe.top + 8, width: w, height: 40)
        appBar.frame = CGRect(x: 16, y: statusLabel.frame.maxY + 8, width: w, height: 44)
        keyBar.frame = CGRect(x: 16, y: appBar.frame.maxY + 10, width: w, height: 44)
        keyIcon.frame = CGRect(x: 12, y: 0, width: 28, height: 44)
        keyField.frame = CGRect(x: 44, y: 0, width: 10, height: 44)
        keyBar.viewWithTag(99)?.frame = CGRect(x: 44, y: 0, width: keyBar.bounds.width - 56, height: 44)
        let padTop = keyBar.frame.maxY + 12
        trackpad.frame = CGRect(x: 16, y: padTop, width: w,
                                height: view.bounds.height - padTop - safe.bottom - 12)
        hintLabel.frame = CGRect(x: 8, y: trackpad.bounds.height - 52,
                                 width: trackpad.bounds.width - 16, height: 44)
    }

    func refreshConnectionState() {
        if Desk.shared.desktop != nil {
            statusLabel.text = "🖥  Desktop running on external display"
            statusLabel.textColor = UIColor(red: 0.4, green: 0.85, blue: 0.55, alpha: 1)
        } else {
            statusLabel.text = "Plug in your monitor (USB-C → HDMI/DP)\nKeep DeskDock in the foreground"
            statusLabel.textColor = UIColor(white: 0.6, alpha: 1)
        }
    }

    // MARK: - Trackpad gestures

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: trackpad)
        g.setTranslation(.zero, in: trackpad)
        Desk.shared.desktop?.moveCursor(dx: t.x * 1.6, dy: t.y * 1.6)
    }

    @objc private func onScroll(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: trackpad)
        g.setTranslation(.zero, in: trackpad)
        // Natural scrolling: content follows the fingers.
        Desk.shared.desktop?.scroll(dx: -t.x, dy: -t.y)
    }

    @objc private func onTap(_ g: UITapGestureRecognizer) {
        Desk.shared.desktop?.click()
    }

    @objc private func onPress(_ g: UILongPressGestureRecognizer) {
        let p = g.location(in: trackpad)
        switch g.state {
        case .began:
            haptic.impactOccurred()
            lastPressPoint = p
            Desk.shared.desktop?.beginDrag()
        case .changed:
            let dx = (p.x - lastPressPoint.x) * 1.6
            let dy = (p.y - lastPressPoint.y) * 1.6
            lastPressPoint = p
            Desk.shared.desktop?.moveCursor(dx: dx, dy: dy)
            Desk.shared.desktop?.dragMoved()
        default:
            Desk.shared.desktop?.endDrag()
        }
    }

    // MARK: - Keyboard forwarding

    @objc private func focusKeyboard() {
        keyField.becomeFirstResponder()
    }

    @objc private func openApp(_ sender: UIButton) {
        guard let kind = DeskAppKind.from(tag: sender.tag) else { return }
        Desk.shared.desktop?.openApp(kind)
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if string.isEmpty {
            Desk.shared.desktop?.deleteBackward()
        } else {
            Desk.shared.desktop?.insertText(string)
        }
        textField.text = sentinel
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        Desk.shared.desktop?.insertText("\n")
        return false
    }
}
