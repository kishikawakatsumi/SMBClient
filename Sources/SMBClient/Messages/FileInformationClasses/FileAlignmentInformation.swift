import Foundation

public struct FileAlignmentInformation {
  public let alignmentRequirement: AlignmentRequirement

  public struct AlignmentRequirement: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let byte = AlignmentRequirement(rawValue: 0x00000000)
    public static let word = AlignmentRequirement(rawValue: 0x00000001)
    public static let long = AlignmentRequirement(rawValue: 0x00000003)
    public static let quad = AlignmentRequirement(rawValue: 0x00000007)
    public static let octa = AlignmentRequirement(rawValue: 0x0000000F)
    public static let thirtyTwo = AlignmentRequirement(rawValue: 0x0000001F)
    public static let sixtyFour = AlignmentRequirement(rawValue: 0x0000003F)
    public static let oneTwentyEight = AlignmentRequirement(rawValue: 0x0000007F)
    public static let twoFiftySix = AlignmentRequirement(rawValue: 0x000000FF)
    public static let fiveTwelve = AlignmentRequirement(rawValue: 0x000001FF)
  } 

  public init(data: Data) {
    let byteReader = ByteReader(data)
    alignmentRequirement = AlignmentRequirement(rawValue: byteReader.read())
  }
}

extension ByteReader {
  func read() -> FileAlignmentInformation {
    return FileAlignmentInformation(data: read(count: 4))
  }
}
