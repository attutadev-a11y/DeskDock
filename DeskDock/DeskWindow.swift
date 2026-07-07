import UIKit

/// A draggable, resizable window on the desktop: title bar with a close
/// button, a content area, and a resize grip in the bottom-right corner.
final class DeskWindow: UIView {

    static let titleHeight: CGFloat = 34
    static let minSize = CGSize(width: 300, height: 200)

    let contentView: UIView
    var onClose: ((DeskWindow) -> Void)?

    private let titleBar = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let grip = UILabel()

    init(title: String, frame: CGRect, content: UIView) {
        contentView = content
        super.init(frame: frame)

        backgroundColor = UIColor(white: 0.13, alpha: 1)
        layer.cornerRadius = 10
        layer.masksToBounds = false
        layer.borderWidth = 1.5
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)

        titleBar.backgroundColor = UIColor(white: 0.17, alpha: 1)
        titleBar.layer.cornerRadius = 10
        titleBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(titleBar)

        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        closeButton.backgroundColor = UIColor(red: 0.9, green: 0.3, blue: 0.28, alpha: 1)
        closeButton.layer.cornerRadius = 10
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        titleBar.addSubview(closeButton)

        titleLabel.text = title
        titleLabel.textColor = UIColor(white: 0.85, alpha: 1)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textAlignment = .center
        titleBar.addSubview(titleLabel)

        content.clipsToBounds = true
        content.layer.cornerRadius = 10
        content.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        addSubview(content)

        grip.text = "◢"
        grip.textColor = UIColor(white: 0.45, alpha: 1)
        grip.font = .systemFont(ofSize: 13)
        grip.textAlignment = .center
        addSubview(grip)

        setFocused(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        titleBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: Self.titleHeight)
        closeButton.frame = CGRect(x: 8, y: (Self.titleHeight - 20) / 2, width: 20, height: 20)
        titleLabel.frame = CGRect(x: 36, y: 0, width: bounds.width - 72, height: Self.titleHeight)
        contentView.frame = CGRect(x: 0, y: Self.titleHeight,
                                   width: bounds.width, height: bounds.height - Self.titleHeight)
        grip.frame = CGRect(x: bounds.width - 22, y: bounds.height - 22, width: 20, height: 20)
        bringSubviewToFront(grip)
    }

    func setFocused(_ focused: Bool) {
        layer.borderColor = focused
            ? UIColor(red: 0.31, green: 0.56, blue: 0.97, alpha: 1).cgColor
            : UIColor(white: 0.28, alpha: 1).cgColor
    }

    /// Point is in this window's coordinate space.
    func isResizeGrip(_ p: CGPoint) -> Bool {
        return p.x > bounds.width - 32 && p.y > bounds.height - 32
    }

    @objc private func closeTapped() {
        onClose?(self)
    }
}
