import Foundation

public class FileReader {
  private let session: Session
  private let path: String

  private var createResponse: Create.Response?

  public var fileSize: UInt64 {
    get async throws {
      let fileHandle = try await fileHandle()
      return fileHandle.size
    }
  }

  init(session: Session, path: String) {
    self.session = session
    self.path = path
  }

  public func read(offset: UInt64) async throws -> Data {
    try await read(offset: offset, length: session.maxReadSize)
  }

  public func read(offset: UInt64, length: UInt32) async throws -> Data {
    let readSize = min(length, session.maxReadSize)
    let fileHandle = try await fileHandle()

    var buffer = Data()

    var response: Read.Response
    repeat {
      response = try await session.read(
        fileId: fileHandle.id,
        offset: offset + UInt64(buffer.count),
        length: min(readSize, length - UInt32(truncatingIfNeeded: buffer.count))
      )

      buffer.append(response.buffer)
    } while response.header.status != NTStatus.endOfFile && buffer.count < length && offset + UInt64(buffer.count) < fileHandle.size

    return buffer
  }

  public func download() async throws -> Data {
    let fileHandle = try await fileHandle()

    var offset: UInt64 = 0
    var buffer = Data()

    var response: Read.Response
    repeat {
      response = try await session.read(
        fileId: fileHandle.id,
        offset: offset
      )

      buffer.append(response.buffer)
      offset = UInt64(buffer.count)
    } while response.header.status != NTStatus.endOfFile && buffer.count < fileHandle.size

    return buffer
  }

  public func close() async throws {
    if let createResponse {
      try await session.close(fileId: createResponse.fileId)
    }
    createResponse = nil
  }

  private func fileHandle() async throws -> FileHandle {
    guard let createResponse else {
      let response = try await session.create(
        desiredAccess: [.genericRead],
        fileAttributes: [],
        shareAccess: [.read],
        createDisposition: .open,
        createOptions: [],
        name: path
      )
      createResponse = response
      return FileHandle(id: response.fileId, size: response.endOfFile)
    }
    return FileHandle(id: createResponse.fileId, size: createResponse.endOfFile)
  }
}
