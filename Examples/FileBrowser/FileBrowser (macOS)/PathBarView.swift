import Cocoa

class PathBarView: NSView {
  private(set) var pathControl = NSPathControl()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)

    let visualEffectView = NSVisualEffectView()
    visualEffectView.blendingMode = .withinWindow
    visualEffectView.material = .headerView
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

    pathControl.focusRingType = .none
    pathControl.controlSize = .small
    pathControl.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    
    pathControl.translatesAutoresizingMaskIntoConstraints = false
    visualEffectView.addSubview(pathControl)
    NSLayoutConstraint.activate([
      pathControl.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 4),
      pathControl.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 6),
      pathControl.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -6),
      pathControl.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -4),
    ])
    pathControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  }

  override var allowsVibrancy: Bool {
    true
  }
}
