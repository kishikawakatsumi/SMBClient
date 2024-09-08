import Cocoa
import UniformTypeIdentifiers

struct Icons {
  static var folder: NSImage? {
    NSWorkspace.shared.icon(for: UTType.folder)
  }

  static var file: NSImage? {
    NSWorkspace.shared.icon(for: UTType.item)
  }

  static var server: NSImage? {
    guard let bundle = Bundle(path: "/System/Library/CoreServices/CoreTypes.bundle") else {
      return nil
    }
    guard let url = bundle.urlForImageResource("GenericFileServerIcon.icns") else {
      return nil
    }

    return NSImage(contentsOf: url)
  }
  
  static var share: NSImage? {
    guard let bundle = Bundle(path: "/System/Library/CoreServices/CoreTypes.bundle") else {
      return nil
    }
    guard let url = bundle.urlForImageResource("GroupFolder.icns") else {
      return nil
    }

    return NSImage(contentsOf: url)
  }

  static func icon(for contentType: UTType) -> NSImage {
    NSWorkspace.shared.icon(for: contentType)
  }
}
