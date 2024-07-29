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

extension FileAttributes: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()

    if contains(.readonly) {
      values.append("Read Only")
    }
    if contains(.hidden) {
      values.append("Hidden")
    }
    if contains(.system) {
      values.append("System")
    }
    if contains(.directory) {
      values.append("Directory")
    }
    if contains(.archive) {
      values.append("Requires archived")
    }
    if contains(.normal) {
      values.append("Normal")
    }
    if contains(.temporary) {
      values.append("Temporary")
    }
    if contains(.sparseFile) {
      values.append("Sparse")
    }
    if contains(.reparsePoint) {
      values.append("Reparse Point")
    }
    if contains(.compressed) {
      values.append("Compressed")
    }
    if contains(.offline) {
      values.append("Offline")
    }
    if contains(.notContentIndexed) {
      values.append("Not Content Indexed")
    }
    if contains(.encrypted) {
      values.append("Encrypted")
    }
    if contains(.integrityStream) {
      values.append("Integrity Stream")
    }
    if contains(.noScrubData) {
      values.append("No Scrub Data")
    }
    if contains(.recallOnOpen) {
      values.append("Recall On Open")
    }
    if contains(.pinned) {
      values.append("Pinned")
    }
    if contains(.unpinned) {
      values.append("Unpinned")
    }
    if contains(.recallOnDataAccess) {
      values.append("Recall On Data Access")
    }

    if values.isEmpty {
      return "0x\(String(format: "%08x", rawValue))"
    } else {
      return "0x\(String(format: "%08x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}
