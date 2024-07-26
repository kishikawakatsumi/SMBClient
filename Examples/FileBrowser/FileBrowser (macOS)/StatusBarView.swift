import Cocoa

class StatusBarView: NSView {
  private(set) var label = NSTextField(labelWithString: "")

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)

    let visualEffectView = NSVisualEffectView()
    visualEffectView.blendingMode = .withinWindow
    visualEffectView.material = .titlebar
    visualEffectView.state = .followsWindowActiveState

    visualEffectView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(visualEffectView)
    NSLayoutConstraint.activate([
      visualEffectView.topAnchor.constraint(equalTo: topAnchor),
      visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
      visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    let border = NSBox()
    border.boxType = .separator

    border.translatesAutoresizingMaskIntoConstraints = false
    visualEffectView.addSubview(border)
    NSLayoutConstraint.activate([
      border.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
      border.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
      border.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
    ])

    label.usesSingleLineMode = true
    label.focusRingType = .none
    label.controlSize = .small
    label.alignment = .center
    label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = .secondaryLabelColor

    label.translatesAutoresizingMaskIntoConstraints = false
    visualEffectView.addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 20),
      label.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -20),
      label.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
    ])

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive(_:)),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidResignActive(_:)),
      name: NSApplication.didResignActiveNotification,
      object: nil
    )
  }

  override var allowsVibrancy: Bool {
    true
  }

  @objc
  private func applicationDidBecomeActive(_ notification: Notification) {
    label.textColor = .secondaryLabelColor
  }

  @objc
  private func applicationDidResignActive(_ notification: Notification) {
    label.textColor = .disabledControlTextColor
  }
}
