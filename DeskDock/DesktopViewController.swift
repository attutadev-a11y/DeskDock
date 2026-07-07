import UIKit
import WebKit

enum DeskAppKind: String, CaseIterable {
    case code = "Code"
    case browser = "Browser"
    case notes = "Notes"

    var tag: Int {
        switch self {
        case .code: return 1
        case .browser: return 2
        case .notes: return 3
        }
    }

    static func from(tag: Int) -> DeskAppKind? {
        return allCases.first { $0.tag == tag }
    }
}

/// The desktop environment rendered on the external display: wallpaper,
/// taskbar, cursor, and a stack of DeskWindows. All input arrives as
/// synthetic events from the phone's trackpad scene.
final class DesktopViewController: UIViewController {

    private let wallpaper = CAGradientLayer()
    private let taskbar = UIView()
    private let brandLabel = UILabel()
    private let clockLabel = UILabel()
    private var clockTimer: Timer?
    private let hintLabel = UILabel()
    private let cursor = CursorView()

    private var windows: [DeskWindow] = []
    private var cursorPos = CGPoint(x: 300, y: 200)
    private var didPlaceCursor = false

    private enum DragMode {
        case none
        case move(DeskWindow, grabOffset: CGPoint)
        case resize(DeskWindow)
    }
    private var dragMode: DragMode = .none

    /// The text view / text field / web view that typed keys are routed to.
    private weak var focusedText: UIView?

    private let taskbarHeight: CGFloat = 46

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        wallpaper.colors = [
            UIColor(red: 0.07, green: 0.09, blue: 0.18, alpha: 1).cgColor,
            UIColor(red: 0.12, green: 0.07, blue: 0.22, alpha: 1).cgColor,
            UIColor(red: 0.04, green: 0.13, blue: 0.20, alpha: 1).cgColor,
        ]
        wallpaper.startPoint = CGPoint(x: 0, y: 0)
        wallpaper.endPoint = CGPoint(x: 1, y: 1)
        view.layer.addSublayer(wallpaper)

        hintLabel.text = "DeskDock\nYour iPhone is the trackpad — tap the taskbar or the buttons on your phone to open apps"
        hintLabel.font = .systemFont(ofSize: 17)
        hintLabel.textColor = UIColor(white: 1, alpha: 0.35)
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center
        view.addSubview(hintLabel)

        taskbar.backgroundColor = UIColor(white: 0.1, alpha: 0.92)
        view.addSubview(taskbar)

        brandLabel.text = "🖥 DeskDock"
        brandLabel.font = .systemFont(ofSize: 14, weight: .bold)
        brandLabel.textColor = UIColor(white: 0.9, alpha: 1)
        taskbar.addSubview(brandLabel)

        for kind in DeskAppKind.allCases {
            let b = UIButton(type: .system)
            b.setTitle(kind.rawValue, for: .normal)
            b.setTitleColor(.white, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            b.backgroundColor = UIColor(white: 0.22, alpha: 1)
            b.layer.cornerRadius = 8
            b.tag = kind.tag
            b.addTarget(self, action: #selector(taskbarTapped(_:)), for: .touchUpInside)
            taskbar.addSubview(b)
        }

        clockLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        clockLabel.textColor = UIColor(white: 0.85, alpha: 1)
        clockLabel.textAlignment = .right
        taskbar.addSubview(clockLabel)
        updateClock()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateClock()
        }

        cursor.isUserInteractionEnabled = false
        view.addSubview(cursor)
    }

    deinit {
        clockTimer?.invalidate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        wallpaper.frame = view.bounds
        taskbar.frame = CGRect(x: 0, y: view.bounds.height - taskbarHeight,
                               width: view.bounds.width, height: taskbarHeight)
        brandLabel.frame = CGRect(x: 14, y: 0, width: 110, height: taskbarHeight)
        var x: CGFloat = 134
        for case let b as UIButton in taskbar.subviews where b.tag > 0 {
            b.frame = CGRect(x: x, y: 8, width: 84, height: taskbarHeight - 16)
            x += 94
        }
        clockLabel.frame = CGRect(x: taskbar.bounds.width - 110, y: 0, width: 96, height: taskbarHeight)
        hintLabel.frame = view.bounds.insetBy(dx: 60, dy: 60)
        if !didPlaceCursor {
            didPlaceCursor = true
            cursorPos = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            cursor.frame.origin = cursorPos
        }
    }

    private func updateClock() {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        clockLabel.text = f.string(from: Date())
    }

    // MARK: - Opening apps

    @objc private func taskbarTapped(_ sender: UIButton) {
        guard let kind = DeskAppKind.from(tag: sender.tag) else { return }
        openApp(kind)
    }

    func openApp(_ kind: DeskAppKind) {
        let content: UIView
        var size = CGSize(width: 640, height: 460)
        switch kind {
        case .code:
            content = CodeEditorView()
            size = CGSize(width: 700, height: 520)
        case .browser:
            content = BrowserView()
            size = CGSize(width: 820, height: 560)
        case .notes:
            content = NotesView()
            size = CGSize(width: 440, height: 420)
        }
        let cascade = CGFloat(windows.count % 6) * 32
        let origin = CGPoint(x: 60 + cascade, y: 50 + cascade)
        let win = DeskWindow(title: kind.rawValue,
                             frame: CGRect(origin: origin, size: size),
                             content: content)
        win.onClose = { [weak self] w in self?.close(w) }
        windows.append(win)
        view.addSubview(win)
        focus(win)
        hintLabel.isHidden = true
    }

    private func close(_ win: DeskWindow) {
        windows.removeAll { $0 === win }
        if let ft = focusedText, ft.isDescendant(of: win) { focusedText = nil }
        win.removeFromSuperview()
        if windows.isEmpty { hintLabel.isHidden = false }
        if let top = windows.last { focus(top) }
    }

    private func focus(_ win: DeskWindow) {
        for w in windows { w.setFocused(w === win) }
        if let idx = windows.firstIndex(where: { $0 === win }) {
            windows.append(windows.remove(at: idx))
        }
        view.bringSubviewToFront(win)
        view.bringSubviewToFront(taskbar)
        view.bringSubviewToFront(cursor)
    }

    // MARK: - Cursor + click events (from the phone)

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        cursorPos.x = min(max(cursorPos.x + dx, 0), view.bounds.width - 2)
        cursorPos.y = min(max(cursorPos.y + dy, 0), view.bounds.height - 2)
        cursor.frame.origin = cursorPos
    }

    func click() {
        cursor.flash()
        guard let hit = view.hitTest(cursorPos, with: nil) else { return }
        if let win = ancestor(of: hit, as: DeskWindow.self) { focus(win) }

        if let field = ancestor(of: hit, as: UITextField.self) {
            focusedText = field
            markFocused(field)
            return
        }
        if let textView = ancestor(of: hit, as: UITextView.self), textView.isEditable {
            focusedText = textView
            let local = view.convert(cursorPos, to: textView)
            if let pos = textView.closestPosition(to: local) {
                let offset = textView.offset(from: textView.beginningOfDocument, to: pos)
                textView.selectedRange = NSRange(location: offset, length: 0)
            }
            markFocused(textView)
            return
        }
        if let web = ancestor(of: hit, as: WKWebView.self) {
            focusRing?.layer.borderColor = UIColor.clear.cgColor
            focusRing = nil
            focusedText = web
            let local = view.convert(cursorPos, to: web)
            web.evaluateJavaScript(Self.clickScript(x: local.x, y: local.y), completionHandler: nil)
            return
        }
        if let control = ancestor(of: hit, as: UIControl.self) {
            control.sendActions(for: .touchUpInside)
            return
        }
    }

    private weak var focusRing: UIView?
    private func markFocused(_ v: UIView) {
        focusRing?.layer.borderColor = UIColor.clear.cgColor
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor(red: 0.31, green: 0.56, blue: 0.97, alpha: 0.9).cgColor
        focusRing = v
    }

    // MARK: - Dragging (move / resize windows)

    func beginDrag() {
        guard let hit = view.hitTest(cursorPos, with: nil),
              let win = ancestor(of: hit, as: DeskWindow.self) else { return }
        focus(win)
        let local = view.convert(cursorPos, to: win)
        if win.isResizeGrip(local) {
            dragMode = .resize(win)
        } else {
            let grab = CGPoint(x: cursorPos.x - win.frame.minX, y: cursorPos.y - win.frame.minY)
            dragMode = .move(win, grabOffset: grab)
        }
    }

    func dragMoved() {
        switch dragMode {
        case .none:
            break
        case .move(let win, let grab):
            var origin = CGPoint(x: cursorPos.x - grab.x, y: cursorPos.y - grab.y)
            origin.x = min(max(origin.x, -win.frame.width + 80), view.bounds.width - 80)
            origin.y = min(max(origin.y, 0), view.bounds.height - DeskWindow.titleHeight - taskbarHeight)
            win.frame.origin = origin
        case .resize(let win):
            let w = max(DeskWindow.minSize.width, cursorPos.x - win.frame.minX + 10)
            let maxH = view.bounds.height - taskbarHeight - win.frame.minY
            let h = max(DeskWindow.minSize.height, min(cursorPos.y - win.frame.minY + 10, maxH))
            win.frame.size = CGSize(width: w, height: h)
            win.setNeedsLayout()
        }
    }

    func endDrag() {
        dragMode = .none
    }

    // MARK: - Scrolling

    func scroll(dx: CGFloat, dy: CGFloat) {
        guard let hit = view.hitTest(cursorPos, with: nil),
              let sv = ancestor(of: hit, as: UIScrollView.self) else { return }
        var o = sv.contentOffset
        let minX = -sv.adjustedContentInset.left
        let minY = -sv.adjustedContentInset.top
        let maxX = max(minX, sv.contentSize.width + sv.adjustedContentInset.right - sv.bounds.width)
        let maxY = max(minY, sv.contentSize.height + sv.adjustedContentInset.bottom - sv.bounds.height)
        o.x = min(max(o.x + dx, minX), maxX)
        o.y = min(max(o.y + dy, minY), maxY)
        sv.setContentOffset(o, animated: false)
    }

    // MARK: - Keyboard routing

    func insertText(_ s: String) {
        if let tv = focusedText as? UITextView {
            insert(s, into: tv)
        } else if let tf = focusedText as? UITextField {
            if s == "\n" {
                tf.sendActions(for: .editingDidEndOnExit)
            } else {
                tf.text = (tf.text ?? "") + s
                tf.sendActions(for: .editingChanged)
            }
        } else if let web = focusedText as? WKWebView {
            web.evaluateJavaScript(Self.typeScript(s), completionHandler: nil)
        }
    }

    func deleteBackward() {
        if let tv = focusedText as? UITextView {
            let ns = tv.textStorage.string as NSString
            var sel = tv.selectedRange
            sel.location = min(sel.location, ns.length)
            sel.length = min(sel.length, ns.length - sel.location)
            if sel.length > 0 {
                tv.textStorage.replaceCharacters(in: sel, with: "")
                tv.selectedRange = NSRange(location: sel.location, length: 0)
            } else if sel.location > 0 {
                // Delete a whole composed character (emoji are 2+ UTF-16 units).
                let r = ns.rangeOfComposedCharacterSequence(at: sel.location - 1)
                tv.textStorage.replaceCharacters(in: r, with: "")
                tv.selectedRange = NSRange(location: r.location, length: 0)
            }
            tv.delegate?.textViewDidChange?(tv)
        } else if let tf = focusedText as? UITextField {
            if let t = tf.text, !t.isEmpty {
                tf.text = String(t.dropLast())
                tf.sendActions(for: .editingChanged)
            }
        } else if let web = focusedText as? WKWebView {
            let js = "(function(){var el=document.activeElement;" +
                     "if(el&&typeof el.value==='string'){el.value=Array.from(el.value).slice(0,-1).join('');" +
                     "el.dispatchEvent(new Event('input',{bubbles:true}));}})()"
            web.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func insert(_ s: String, into tv: UITextView) {
        let ns = (tv.text ?? "") as NSString
        var sel = tv.selectedRange
        sel.location = min(sel.location, ns.length)
        sel.length = min(sel.length, ns.length - sel.location)
        let attributed = NSAttributedString(string: s, attributes: tv.typingAttributes)
        tv.textStorage.replaceCharacters(in: sel, with: attributed)
        tv.selectedRange = NSRange(location: sel.location + (s as NSString).length, length: 0)
        tv.delegate?.textViewDidChange?(tv)
        tv.scrollRangeToVisible(tv.selectedRange)
    }

    // MARK: - Helpers

    private func ancestor<T: UIView>(of v: UIView, as type: T.Type) -> T? {
        var cur: UIView? = v
        while let c = cur {
            if let match = c as? T { return match }
            cur = c.superview
        }
        return nil
    }

    private static func clickScript(x: CGFloat, y: CGFloat) -> String {
        let ix = Int(x), iy = Int(y)
        return "(function(){var el=document.elementFromPoint(\(ix),\(iy));if(el){" +
               "if(el.focus)el.focus();" +
               "el.dispatchEvent(new MouseEvent('click',{clientX:\(ix),clientY:\(iy),bubbles:true,cancelable:true}));}})()"
    }

    private static func typeScript(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
        return "(function(){var el=document.activeElement;" +
               "if(el&&typeof el.value==='string'){" +
               "if('\(escaped)'==='\\n'&&el.form){el.form.submit();return;}" +
               "el.value+='\(escaped)';" +
               "el.dispatchEvent(new Event('input',{bubbles:true}));}})()"
    }
}

/// The arrow pointer drawn on the external display.
final class CursorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 24, height: 28))
        backgroundColor = .clear
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 1, y: 1))
        path.addLine(to: CGPoint(x: 1, y: 20))
        path.addLine(to: CGPoint(x: 6, y: 15.5))
        path.addLine(to: CGPoint(x: 9.5, y: 24))
        path.addLine(to: CGPoint(x: 13, y: 22.5))
        path.addLine(to: CGPoint(x: 9.5, y: 14))
        path.addLine(to: CGPoint(x: 16, y: 14))
        path.close()
        let shape = CAShapeLayer()
        shape.path = path.cgPath
        shape.fillColor = UIColor.white.cgColor
        shape.strokeColor = UIColor.black.cgColor
        shape.lineWidth = 1.2
        layer.addSublayer(shape)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func flash() {
        alpha = 0.5
        UIView.animate(withDuration: 0.18) { self.alpha = 1 }
    }
}
