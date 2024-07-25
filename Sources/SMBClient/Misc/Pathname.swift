import Foundation

enum Pathname {
  public static func join(_ paths: String...) -> String {
    guard let first = paths.first else { return "" }
    if first.isEmpty {
      return paths.dropFirst().joined(separator: #"\"#)
    } else {
      return paths.joined(separator: #"\"#)
    }
  }

  static func escape(_ path: String) -> String {
    path.replacingOccurrences(of: "/", with: #"\"#)
  }
}
