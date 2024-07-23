import Foundation

public struct FileModeInformation {
  public let mode: Mode

  public struct Mode: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let writeThrough = Mode(rawValue: 0x00000002)
    public static let sequentialOnly = Mode(rawValue: 0x00000004)
    public static let noIntermediateBuffering = Mode(rawValue: 0x00000008)
    public static let synchronousIoAlert = Mode(rawValue: 0x00000010)
    public static let synchronousIoNonAlert = Mode(rawValue: 0x00000020)
    public static let deleteOnClose = Mode(rawValue: 0x00001000)
  }

  public init(data: Data) {
    let reader = ByteReader(data)
    mode = Mode(rawValue: reader.read())
  }
}

extension ByteReader {
  func read() -> FileModeInformation {
    FileModeInformation(data: read(count: 4))
  }
}
