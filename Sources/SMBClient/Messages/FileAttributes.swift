import Foundation

public struct FileAttributes: OptionSet, Sendable {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let readonly = FileAttributes(rawValue: 0x00000001)
  public static let hidden = FileAttributes(rawValue: 0x00000002)
  public static let system = FileAttributes(rawValue: 0x00000004)
  public static let directory = FileAttributes(rawValue: 0x00000010)
  public static let archive = FileAttributes(rawValue: 0x00000020)
  public static let normal = FileAttributes(rawValue: 0x00000080)
  public static let temporary = FileAttributes(rawValue: 0x00000100)
  public static let sparseFile = FileAttributes(rawValue: 0x00000200)
  public static let reparsePoint = FileAttributes(rawValue: 0x00000400)
  public static let compressed = FileAttributes(rawValue: 0x00000800)
  public static let offline = FileAttributes(rawValue: 0x00001000)
  public static let notContentIndexed = FileAttributes(rawValue: 0x00002000)
  public static let encrypted = FileAttributes(rawValue: 0x00004000)
  public static let integrityStream = FileAttributes(rawValue: 0x00008000)
  public static let noScrubData = FileAttributes(rawValue: 0x00020000)
  public static let recallOnOpen = FileAttributes(rawValue: 0x00040000)
  public static let pinned = FileAttributes(rawValue: 0x00080000)
  public static let unpinned = FileAttributes(rawValue: 0x00100000)
  public static let recallOnDataAccess = FileAttributes(rawValue: 0x00400000)
}

extension FileAttributes: CustomStringConvertible {
  public var description: String {
    var attributes = [String]()

    if contains(.readonly) {
      attributes.append("readonly")
    }
    if contains(.hidden) {
      attributes.append("hidden")
    }
    if contains(.system) {
      attributes.append("system")
    }
    if contains(.directory) {
      attributes.append("directory")
    }
    if contains(.archive) {
      attributes.append("archive")
    }
    if contains(.normal) {
      attributes.append("normal")
    }
    if contains(.temporary) {
      attributes.append("temporary")
    }
    if contains(.sparseFile) {
      attributes.append("sparseFile")
    }
    if contains(.reparsePoint) {
      attributes.append("reparsePoint")
    }
    if contains(.compressed) {
      attributes.append("compressed")
    }
    if contains(.offline) {
      attributes.append("offline")
    }
    if contains(.notContentIndexed) {
      attributes.append("notContentIndexed")
    }
    if contains(.encrypted) {
      attributes.append("encrypted")
    }
    if contains(.integrityStream) {
      attributes.append("integrityStream")
    }
    if contains(.noScrubData) {
      attributes.append("noScrubData")
    }
    if contains(.recallOnOpen) {
      attributes.append("recallOnOpen")
    }
    if contains(.pinned) {
      attributes.append("pinned")
    }
    if contains(.unpinned) {
      attributes.append("unpinned")
    }
    if contains(.recallOnDataAccess) {
      attributes.append("recallOnDataAccess")
    }
    return attributes.joined(separator: ", ")
  }
}
