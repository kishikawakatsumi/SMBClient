import Foundation

public class Session {
  private var messageId = SequenceNumber<UInt64>()
  private var sessionId: UInt64 = 0
  private var treeId: UInt32 = 0

  private var signingKey: Data?

  public private(set) var maxTransactSize: UInt32 = 0
  public private(set) var maxReadSize: UInt32 = 0
  public private(set) var maxWriteSize: UInt32 = 0

  public var server: String { connection.host }
  public private(set) var connectedTree: String?

  public var onDisconnected: (Error) -> Void {
    didSet {
      connection.onDisconnected = onDisconnected
    }
  }

  private let connection: Connection

  public init(host: String) {
    connection = Connection(host: host)
    onDisconnected = { _ in }
  }

  public init(host: String, port: Int) {
    connection = Connection(host: host, port: port)
    onDisconnected = { _ in }
  }

  public func connect() async throws {
    try await connection.connect()
  }

  public func disconnect() {
    connection.disconnect()
  }

  @discardableResult
  public func login(
    username: String?,
    password: String?,
    domain: String? = nil
  ) async throws -> SessionSetup.Response {
    let response = try await sessionSetup(username: username, password: password, domain: domain)
    sessionId = response.header.sessionId
    return response
  }

  @discardableResult
  public func logoff() async throws -> Logoff.Response {
    let request = Logoff.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId
    )
    let data = try await send(request.encoded())
    let response = Logoff.Response(data: data)
    sessionId = 0
    return response
  }

  public func enumShareAll() async throws -> [Share] {
    try await treeConnect(path: "IPC$")

    let createResponse = try await create(
      desiredAccess: [],
      fileAttributes: [.normal],
      shareAccess: [.read, .write],
      createDisposition: .open,
      createOptions: [],
      name: "srvsvc"
    )
    try await bind(fileId: createResponse.fileId)
    let ioCtlResponse = try await netShareEnum(fileId: createResponse.fileId)

    let rpcResponse = DCERPC.Response(data: ioCtlResponse.buffer)
    let netShareEnumResponse = DCERPC.NetShareEnumResponse(data: rpcResponse.stub)

    let shares = netShareEnumResponse.shareInfo1.shareInfo

    try await close(fileId: createResponse.fileId)

    return shares.compactMap {
      switch $0.type {
      case 0x0:
        return Share(name: $0.name.value, comment: $0.comment.value, type: .diskDrive)
      case 0x1:
        return Share(name: $0.name.value, comment: $0.comment.value, type: .printQueue)
      case 0x2:
        return Share(name: $0.name.value, comment: $0.comment.value, type: .device)
      case 0x3:
        return Share(name: $0.name.value, comment: $0.comment.value, type: .ipc)
      case 0x80000000:
        return Share(name: $0.name.value, comment: $0.comment.value, type: .diskDriveAdmin)
      case 0x80000001:
        return Share(name: $0.name.value, comment: $0.comment.value, type: .printQueueAdmin)
      case 0x80000002:
        return Share(name: $0.name.value, comment: $0.comment.value, type: .deviceAdmin)
      case 0x80000003:
        return Share(name: $0.name.value, comment: $0.comment.value, type: .ipcAdmin)
      default:
        return nil
      }
    }
  }

  @discardableResult
  public func negotiate(
    securityMode: Negotiate.SecurityMode = [.signingEnabled],
    dialects: [Negotiate.Dialects] = [.smb202, .smb210]
  ) async throws -> Negotiate.Response {
    let request = Negotiate.Request(
      messageId: messageId.next(),
      securityMode: securityMode,
      dialects: dialects
    )
    let data = try await send(request.encoded())
    let response = Negotiate.Response(data: data)

    maxTransactSize = response.maxTransactSize
    maxReadSize = response.maxReadSize
    maxWriteSize = response.maxWriteSize

    return response
  }

  public func sessionSetup(
    username: String?,
    password: String?,
    domain: String? = nil,
    workstation: String? = nil
  ) async throws -> SessionSetup.Response {
    try await negotiate()

    let negotiateMessage = NTLM.NegotiateMessage(
      domainName: domain,
      workstationName: workstation
    )
    let securityBuffer = negotiateMessage.encoded()

    let request = SessionSetup.Request(
      messageId: messageId.next(),
      securityMode: [.signingEnabled],
      capabilities: [],
      previousSessionId: 0,
      securityBuffer: securityBuffer
    )
    let response = SessionSetup.Response(
      data: try await send(request.encoded())
    )

    if response.header.status == NTStatus.moreProcessingRequired {
      let challengeMessage = NTLM.ChallengeMessage(
        data: response.buffer
      )

      let signingKey = Crypto.randomBytes(count: 16)
      let authenticateMessage = challengeMessage.authenticateMessage(
        username: username,
        password: password,
        domain: domain,
        negotiateMessage: securityBuffer,
        signingKey: signingKey
      )

      let request = SessionSetup.Request(
        messageId: messageId.next(),
        sessionId: response.header.sessionId,
        securityMode: [.signingEnabled],
        capabilities: [],
        previousSessionId: 0,
        securityBuffer: authenticateMessage.encoded()
      )

      let data = try await send(request.encoded())
      self.signingKey = signingKey
      return SessionSetup.Response(data: data)
    } else {
      return response
    }
  }

  @discardableResult
  public func treeConnect(path: String) async throws -> TreeConnect.Response {
    let request = TreeConnect.Request(
      messageId: messageId.next(),
      sessionId: sessionId,
      path: path
    )

    let data = try await send(request.encoded())
    let response = TreeConnect.Response(data: data)

    treeId = response.header.treeId
    connectedTree = path
    return response
  }

  @discardableResult
  public func treeDisconnect() async throws -> TreeDisconnect.Response {
    let request = TreeDisconnect.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId
    )

    let data = try await send(request.encoded())
    let response = TreeDisconnect.Response(data: data)
    
    treeId = 0
    connectedTree = nil

    return response
  }

  public func create(
    desiredAccess: FilePipePrinterAccessMask,
    fileAttributes: FileAttributes,
    shareAccess: Create.Request.ShareAccess,
    createDisposition: Create.Request.CreateDisposition,
    createOptions: Create.Request.CreateOptions,
    name: String
  ) async throws -> Create.Response {
    let request = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: desiredAccess,
      fileAttributes: fileAttributes,
      shareAccess: shareAccess,
      createDisposition: createDisposition,
      createOptions: createOptions,
      name: name
    )

    let data = try await send(request.encoded())
    return Create.Response(data: data)
  }

  public func read(fileId: Data, offset: UInt64) async throws -> Read.Response {
    try await read(fileId: fileId, offset: offset, length: maxReadSize)
  }

  public func read(fileId: Data, offset: UInt64, length: UInt32) async throws -> Read.Response {
    let readSize = min(length, maxReadSize)
    let creditSize = creditSize(size: readSize)

    let request = Read.Request(
      creditRequest: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId,
      offset: offset,
      length: readSize
    )

    let response = Read.Response(data: try await send(request.encoded()))
    return response
  }

  @discardableResult
  public func write(data: Data, fileId: Data, offset: UInt64) async throws -> Write.Response {
    try await write(data: data, fileId: fileId, offset: offset, length: maxWriteSize)
  }

  @discardableResult
  public func write(data: Data, fileId: Data, offset: UInt64, length: UInt32) async throws -> Write.Response {
    let writeSize = min(length, maxWriteSize)
    let creditSize = creditSize(size: writeSize)

    let request = Write.Request(
      creditRequest: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId,
      offset: offset,
      data: data
    )

    let response = Write.Response(data: try await send(request.encoded()))
    return response
  }

  @discardableResult
  public func close(fileId: Data) async throws -> Close.Response {
    let request = Close.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId
    )

    let data = try await send(request.encoded())
    return Close.Response(data: data)
  }

  public func queryDirectory(path: String, pattern: String) async throws -> [QueryDirectory.Response.FileIdBothDirectoryInformation] {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readData, .readAttributes, .synchronize],
      fileAttributes: [.directory],
      shareAccess: [.read, .write, .delete],
      createDisposition: .open,
      createOptions: [.directoryFile],
      name: path
    )

    let queryDirectoryRequest = QueryDirectory.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileInformationClass: .fileIdBothDirectoryInformation,
      fileId: temporaryUUID,
      fileName: pattern
    )

    let data = try await send(
      createRequest.encoded(),
      queryDirectoryRequest.encoded()
    )

    let createResponse = Create.Response(data: data)

    var files = [QueryDirectory.Response.FileIdBothDirectoryInformation]()

    let queryDirectoryResponse = QueryDirectory.Response(data: Data(data[createResponse.header.nextCommand...]))
    files.append(contentsOf: queryDirectoryResponse.files)

    if createResponse.header.status != NTStatus.noMoreFiles {
      repeat {
        let fileId = createResponse.fileId

        let queryDirectoryRequest = QueryDirectory.Request(
          messageId: messageId.next(),
          treeId: treeId,
          sessionId: sessionId,
          fileInformationClass: .fileIdBothDirectoryInformation,
          flags2: [],
          fileId: fileId,
          fileName: pattern
        )

        let data = try await send(queryDirectoryRequest.encoded())
        let queryDirectoryResponse = QueryDirectory.Response(data: data)
        files.append(contentsOf: queryDirectoryResponse.files)

        if queryDirectoryResponse.header.status == NTStatus.noMoreFiles {
          break
        }
      } while true
    }

    try await close(fileId: createResponse.fileId)

    return files
  }

  public func fileStat(path: String) async throws -> Create.Response {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readData, .readAttributes, .synchronize],
      fileAttributes: [],
      shareAccess: [.read, .write, .delete],
      createDisposition: .open,
      createOptions: [],
      name: path
    )
    let closeRequest = Close.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    let data = try await send(
      createRequest.encoded(),
      closeRequest.encoded()
    )

    let createResponse = Create.Response(data: data)
    return createResponse
  }

  public func existFile(path: String) async throws -> Bool {
    do {
      _ = try await fileStat(path: path)
      return true
    } catch let error as ErrorResponse {
      if error.header.status == ErrorCodes.objectNameNotFound {
        return false
      }
      throw error
    } catch {
      throw error
    }
  }

  public func existDirectory(path: String) async throws -> Bool {
    do {
      let stat = try await fileStat(path: path)
      return stat.fileAttributes.contains(.directory)
    } catch let error as ErrorResponse {
      if error.header.status == ErrorCodes.objectNameNotFound {
        return false
      }
      throw error
    } catch {
      throw error
    }
  }

  public func queryInfo(path: String, fileInfoClass: FileInfoClass = .fileAllInformation) async throws -> QueryInfo.Response {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes],
      fileAttributes: [],
      shareAccess: [.read],
      createDisposition: .open,
      createOptions: [],
      name: path
    )
    let queryInfoRequest = QueryInfo.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      infoType: .file,
      fileInfoClass: fileInfoClass,
      fileId: temporaryUUID
    )
    let closeRequest = Close.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    let data = try await send(
      createRequest.encoded(),
      queryInfoRequest.encoded(),
      closeRequest.encoded()
    )

    let createResponse = Create.Response(data: data)
    let queryInfoResponse = QueryInfo.Response(data: Data(data[createResponse.header.nextCommand...]))
    return queryInfoResponse
  }

  @discardableResult
  public func createDirectory(path: String) async throws -> Create.Response {
    let response = try await create(
      desiredAccess: [.readData, .readAttributes],
      fileAttributes: [],
      shareAccess: [.read, .write, .delete],
      createDisposition: .create,
      createOptions: [.directoryFile],
      name: path
    )
    try await close(fileId: response.fileId)
    return response
  }

  public func copy(path source: String, path dest: String) async throws {
    let createResponse = try await create(
      desiredAccess: [.genericRead],
      fileAttributes: [],
      shareAccess: [.read],
      createDisposition: .open,
      createOptions: [],
      name: source
    )

    let creditSize = creditSize(size: maxReadSize)
    let request = Read.Request(
      creditRequest: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileId: createResponse.fileId,
      offset: 0,
      length: maxReadSize
    )

    var buffer = Data()
    var response = Read.Response(data: try await send(request.encoded()))
    buffer.append(response.buffer)

    while response.header.status != NTStatus.endOfFile {
      let request = Read.Request(
        creditRequest: creditSize,
        messageId: messageId.next(count: UInt64(creditSize)),
        treeId: treeId,
        sessionId: sessionId,
        fileId: createResponse.fileId,
        offset: UInt64(buffer.count),
        length: maxReadSize
      )

      let data = try await send(request.encoded())
      response = Read.Response(data: data)
      buffer.append(response.buffer)
    }

    try await close(fileId: createResponse.fileId)
  }

  public func deleteDirectory(path: String) async throws {
    let files = try await queryDirectory(path: path, pattern: "*")
    for file in files {
      guard file.fileName != "." && file.fileName != ".." else {
        continue
      }
      if file.fileAttributes.contains(.directory) {
        try await deleteDirectory(path: "\(path)/\(file.fileName)")
      } else {
        try await deleteFile(path: "\(path)/\(file.fileName)")
      }
    }

    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes, .delete, .synchronize],
      fileAttributes: [.directory],
      shareAccess: [],
      createDisposition: .open,
      createOptions: [.directoryFile],
      name: path
    )
    let setInfoRequest = SetInfo.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileDispositionInformation(deletePending: true)
    )
    let closeRequest = Close.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(
      createRequest.encoded(),
      setInfoRequest.encoded(),
      closeRequest.encoded()
    )
  }

  public func deleteFile(path: String) async throws {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes, .delete, .synchronize],
      fileAttributes: [.normal],
      shareAccess: [],
      createDisposition: .open,
      createOptions: [],
      name: path
    )
    let setInfoRequest = SetInfo.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileDispositionInformation(deletePending: true)
    )
    let closeRequest = Close.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(
      createRequest.encoded(),
      setInfoRequest.encoded(),
      closeRequest.encoded()
    )
  }

  public func move(from: String, to: String) async throws {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes, .delete, .synchronize],
      fileAttributes: [.normal],
      shareAccess: [],
      createDisposition: .open,
      createOptions: [],
      name: from
    )
    let setInfoRequest = SetInfo.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileRenameInformation(fileName: to)
    )
    let closeRequest = Close.Request(
      flags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(
      createRequest.encoded(),
      setInfoRequest.encoded(),
      closeRequest.encoded()
    )
  }

  @discardableResult
  func bind(fileId: Data) async throws -> IOCtl.Response {
    let input = DCERPC.Bind(
      callID: 1,
      context: DCERPC.Bind.ContextList(
        items: [
          DCERPC.Bind.PresentationContext(
            contextID: 0,
            abstractSyntax: DCERPC.Bind.AbstractSyntax(),
            transferSyntaxes: [
              DCERPC.Bind.TransferSyntax()
            ]
          )
        ]
      )
    )

    let request = IOCtl.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      ctlCode: .pipeTransceive,
      fileId: fileId,
      input: input.encoded(),
      output: Data()
    )

    let data = try await send(request.encoded())
    return IOCtl.Response(data: data)
  }

  func netShareEnum(fileId: Data) async throws -> IOCtl.Response {
    let netShareEnum = DCERPC.NetShareEnum(serverName: connection.host)

    let input = DCERPC.Request(
      callID: 0,
      opnum: .netrShareEnum,
      stub: netShareEnum.encoded()
    )

    let request = IOCtl.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      ctlCode: .pipeTransceive,
      fileId: fileId,
      input: input.encoded(),
      output: Data()
    )

    let data = try await send(request.encoded())
    return IOCtl.Response(data: data)
  }

  private func send(_ payload: Data) async throws -> Data {
    try await connection.send(sign(payload))
  }

  private func send(_ payloads: Data...) async throws -> Data {
    return try await connection.send(
      payloads.enumerated().reduce(into: Data()) {
        let alignment = Data(repeating: 0, count: 8 - $1.element.count % 8)
        if $1.offset < payloads.count - 1 {
          let payload = $1.element + alignment
          var header = Header(data: payload[..<64])
          header.nextCommand = UInt32(payload.count)

          $0 += sign(header.encoded() + $1.element[64...] + alignment)
        } else {
          $0 += sign($1.element + alignment)
        }
      }
    )
  }

  private func sign(_ payload: Data) -> Data {
    if let signingKey {
      let signature = Crypto.hmacSHA256(key: signingKey, data: payload)[..<16]
      var header = Header(data: payload[..<64])
      header.signature = signature
      return header.encoded() + payload[64...]
    } else {
      return payload
    }
  }
}

private class SequenceNumber<I: UnsignedInteger & FixedWidthInteger> {
  var current: I = 0

  func next(count: I = 1) -> I {
    let next = current
    current &+= count
    return next
  }
}

private func creditSize(size: UInt32) -> UInt16 {
  UInt16(truncatingIfNeeded: (size - 1) / 65536 + 1)
}
