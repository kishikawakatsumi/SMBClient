import Foundation

public class Session {
  private var messageId = SequenceNumber<UInt64>()
  private var sessionId: UInt64 = 0
  private(set) var treeId: UInt32 = 0

  private var isAnonymous = false
  private var signingRequired = false
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

  public convenience init(host: String) {
    self.init(Connection(host: host))
  }

  public convenience init(host: String, port: Int) {
    self.init(Connection(host: host, port: port))
  }

  private init(_ connection: Connection) {
    self.connection = connection
    onDisconnected = { _ in }
  }

  func newSession() -> Session {
    let session = Session(connection)

    session.messageId = messageId
    session.sessionId = sessionId
    session.treeId = 0

    session.signingRequired = signingRequired
    session.signingKey = signingKey

    session.maxTransactSize = maxTransactSize
    session.maxReadSize = maxReadSize
    session.maxWriteSize = maxWriteSize

    return session
  }

  func treeAccessor(share: String) -> TreeAccessor {
    TreeAccessor(session: self, share: share)
  }

  public func connect() async throws {
    try await connection.connect()
  }

  public func disconnect() {
    connection.disconnect()
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

    let response = try await send(request)

    signingRequired = response.securityMode.contains(.signingRequired)

    maxTransactSize = response.maxTransactSize
    maxReadSize = response.maxReadSize
    maxWriteSize = response.maxWriteSize

    return response
  }

  @discardableResult
  public func sessionSetup(
    username: String?,
    password: String?,
    domain: String? = nil,
    workstation: String? = nil
  ) async throws -> SessionSetup.Response {
    let negotiateMessage = NTLM.NegotiateMessage(
      domainName: domain,
      workstationName: workstation
    )
    let securityBuffer = negotiateMessage.encoded()

    let request = SessionSetup.Request(
      messageId: messageId.next(),
      sessionId: 0,
      securityMode: [.signingEnabled],
      capabilities: [],
      previousSessionId: 0,
      securityBuffer: securityBuffer
    )
    let response = try await send(request)

    if NTStatus(response.header.status) == .moreProcessingRequired {
      let challengeMessage = NTLM.ChallengeMessage(data: response.buffer)

      let signingKey = Crypto.randomBytes(count: 16)
      let authenticateMessage = challengeMessage.authenticateMessage(
        username: username,
        password: password,
        domain: domain,
        workstation: workstation,
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

      let response = try await send(request)

      sessionId = response.header.sessionId

      isAnonymous = (username ?? "").isEmpty && (password ?? "").isEmpty
      self.signingKey = signingKey

      return response
    } else {
      sessionId = response.header.sessionId
      return response
    }
  }

  @discardableResult
  public func logoff() async throws -> Logoff.Response {
    let request = Logoff.Request(
      messageId: messageId.next(),
      sessionId: sessionId
    )

    let response = try await send(request)

    sessionId = 0

    return response
  }

  public func enumShareAll() async throws -> [Share] {
    let treeAccessor = treeAccessor(share: "IPC$")
    let session = try await treeAccessor.session()

    let createResponse = try await session.create(
      desiredAccess: [.readData, .writeData, .appendData, .readAttributes],
      fileAttributes: [.normal],
      shareAccess: [.read, .write],
      createDisposition: .open,
      createOptions: [.nonDirectoryFile],
      name: "srvsvc"
    )

    try await session.bind(fileId: createResponse.fileId)
    let ioCtlResponse = try await session.netShareEnum(fileId: createResponse.fileId)

    let rpcResponse = DCERPC.Response(data: ioCtlResponse.buffer)
    let netShareEnumResponse = NetShareEnumResponse(data: rpcResponse.stub)

    let shares = netShareEnumResponse.shareInfo1.shareInfo

    try await session.close(fileId: createResponse.fileId)

    return shares.compactMap {
      var type = Share.ShareType(rawValue: $0.type & 0x0FFFFFFF)

      if $0.type & Share.ShareType.special.rawValue != 0 {
        type.insert(.special)
      }
      if $0.type & Share.ShareType.temporary.rawValue != 0 {
        type.insert(.temporary)
      }

      return Share(name: $0.name.value, comment: $0.comment.value, type: type)
    }
  }

  @discardableResult
  public func treeConnect(path: String) async throws -> TreeConnect.Response {
    let request = TreeConnect.Request(
      messageId: messageId.next(),
      sessionId: sessionId,
      path: #"\\\#(server)\\#(path)"#
    )

    let response = try await send(request)

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

    let response = try await send(request)

    treeId = 0
    connectedTree = nil

    return response
  }

  public func create(
    desiredAccess: FilePipePrinterAccessMask,
    fileAttributes: FileAttributes,
    shareAccess: Create.ShareAccess,
    createDisposition: Create.CreateDisposition,
    createOptions: Create.CreateOptions,
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

    return try await send(request)
  }

  public func read(fileId: Data, offset: UInt64) async throws -> Read.Response {
    try await read(fileId: fileId, offset: offset, length: maxReadSize)
  }

  public func read(fileId: Data, offset: UInt64, length: UInt32) async throws -> Read.Response {
    let readSize = min(length, maxReadSize)
    let creditSize = creditSize(size: readSize)

    let request = Read.Request(
      creditCharge: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId,
      offset: offset,
      length: readSize
    )

    return try await send(request)
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
      creditCharge: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId,
      offset: offset,
      data: data
    )

    return try await send(request)
  }

  @discardableResult
  public func close(fileId: Data) async throws -> Close.Response {
    let request = Close.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId
    )

    return try await send(request)
  }

  public func queryDirectory(path: String, pattern: String) async throws -> [FileDirectoryInformation] {
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

    let outputBufferLength = min(1048576, maxTransactSize)
    let creditSize = creditSize(size: outputBufferLength)
    let fileInformationClass = QueryDirectory.FileInformationClass.fileDirectoryInformation

    let queryDirectoryRequest = QueryDirectory.Request(
      creditCharge: creditSize,
      headerFlags: [.relatedOperations],
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileInformationClass: fileInformationClass,
      fileId: temporaryUUID,
      fileName: pattern,
      outputBufferLength: outputBufferLength
    )

    let (createResponse, queryDirectoryResponse) = try await send(createRequest, queryDirectoryRequest)

    var files: [FileDirectoryInformation] = queryDirectoryResponse.files()

    if NTStatus(createResponse.header.status) != .noMoreFiles {
      repeat {
        let fileId = createResponse.fileId

        let queryDirectoryRequest = QueryDirectory.Request(
          creditCharge: creditSize,
          messageId: messageId.next(count: UInt64(creditSize)),
          treeId: treeId,
          sessionId: sessionId,
          fileInformationClass: fileInformationClass,
          flags: [],
          fileId: fileId,
          fileName: pattern,
          outputBufferLength: outputBufferLength
        )

        let queryDirectoryResponse = try await send(queryDirectoryRequest)
        files.append(contentsOf: queryDirectoryResponse.files())

        if NTStatus(queryDirectoryResponse.header.status) == .noMoreFiles {
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
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    let (response, _) = try await send(createRequest, closeRequest)
    return response
  }

  public func existFile(path: String) async throws -> Bool {
    do {
      _ = try await fileStat(path: path)
      return true
    } catch let error as ErrorResponse {
      if NTStatus(error.header.status) == .objectNameNotFound {
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
      if NTStatus(error.header.status) == .objectNameNotFound {
        return false
      }
      throw error
    } catch {
      throw error
    }
  }

  public func queryInfo(path: String, infoType: InfoType = .file, fileInfoClass: FileInfoClass = .fileAllInformation) async throws -> QueryInfo.Response {
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
      infoType: infoType,
      fileInfoClass: fileInfoClass,
      fileId: temporaryUUID
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    let (_, response, _) = try await send(createRequest, queryInfoRequest, closeRequest)
    return response
  }

  @discardableResult
  public func createDirectory(path: String) async throws -> Create.Response {
    let response = try await create(
      desiredAccess: [.readData, .readAttributes],
      fileAttributes: [],
      shareAccess: [.read, .write, .delete],
      createDisposition: .create,
      createOptions: [.directoryFile],
      name: path.precomposedStringWithCanonicalMapping
    )
    try await close(fileId: response.fileId)
    return response
  }

  public func deleteDirectory(path: String) async throws {
    let files = try await queryDirectory(path: path, pattern: "*")
    for file in files {
      guard file.fileName != "." && file.fileName != ".." else {
        continue
      }

      let subpath = Pathname.join(path, file.fileName)
      if file.fileAttributes.contains(.directory) {
        try await deleteDirectory(path: subpath)
      } else {
        try await deleteFile(path: subpath)
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
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileDispositionInformation(deletePending: true)
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(createRequest, setInfoRequest, closeRequest)
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
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileDispositionInformation(deletePending: true)
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(createRequest, setInfoRequest, closeRequest)
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
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileRenameInformation(fileName: to.precomposedStringWithCanonicalMapping)
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(createRequest, setInfoRequest, closeRequest)
  }

  @discardableResult
  public func echo() async throws -> Echo.Response {
    let request = Echo.Request(
      messageId: messageId.next(),
      sessionId: sessionId
    )

    return try await send(request)
  }

  @discardableResult
  func bind(fileId: Data) async throws -> IOCtl.Response {
    let input = DCERPC.Bind(
      callID: 1,
      context: DCERPC.ContextList(
        items: [
          DCERPC.PresentationContext(
            contextID: 0,
            abstractSyntax: DCERPC.AbstractSyntax(),
            transferSyntaxes: [
              DCERPC.TransferSyntax()
            ]
          )
        ]
      )
    )

    let creditSize = creditSize(size: maxReadSize)
    let request = IOCtl.Request(
      creditCharge: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      ctlCode: .pipeTransceive,
      fileId: fileId,
      input: input.encoded(),
      output: Data()
    )

    return try await send(request)
  }

  func netShareEnum(fileId: Data) async throws -> IOCtl.Response {
    let netShareEnum = NetShareEnum(serverName: connection.host)

    let input = DCERPC.Request(
      callID: 0,
      opnum: .netrShareEnum,
      stub: netShareEnum.encoded()
    )

    let creditSize = creditSize(size: maxReadSize)
    let request = IOCtl.Request(
      creditCharge: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      ctlCode: .pipeTransceive,
      fileId: fileId,
      input: input.encoded(),
      output: Data()
    )

    return try await send(request)
  }

  private func send<Request: Message.Request>(_ message: Request) async throws -> Request.Response {
    let packet = message.encoded()
    let data = try await connection.send(sign(packet))
    let response = Request.Response(data: data)
    return response
  }

  private func send<R1: Message.Request, R2: Message.Request>(_ m1: R1, _ m2: R2) async throws -> (R1.Response, R2.Response) {
    let data = try await send(m1.encoded(), m2.encoded())
    let r1 = R1.Response(data: data)
    let r2 = R2.Response(data: Data(data[r1.header.nextCommand...]))
    return (r1, r2)
  }

  private func send<R1: Message.Request, R2: Message.Request, R3: Message.Request>(_ m1: R1, _ m2: R2, _ m3: R3) async throws -> (R1.Response, R2.Response, R3.Response) {
    let data = try await send(m1.encoded(), m2.encoded(), m3.encoded())
    let r1 = R1.Response(data: data)
    let r2 = R2.Response(data: Data(data[r1.header.nextCommand...]))
    let r3 = R3.Response(data: Data(data[r2.header.nextCommand...]))
    return (r1, r2, r3)
  }

  private func send(_ packets: Data...) async throws -> Data {
    return try await connection.send(
      packets.enumerated().reduce(into: Data()) {
        let alignment = Data(count: 8 - $1.element.count % 8)
        if $1.offset < packets.count - 1 {
          let packet = $1.element + alignment
          var header = Header(data: packet[..<64])
          let payload = $1.element[64...]

          header.nextCommand = UInt32(packet.count)

          $0 += sign(header.encoded() + payload + alignment)
        } else {
          $0 += sign($1.element + alignment)
        }
      }
    )
  }

  private func sign(_ packet: Data) -> Data {
    if let signingKey, signingRequired, !isAnonymous {
      var header = Header(data: packet[..<64])
      let payload = packet[64...]

      header.flags = header.flags.union(.signed)

      let signature = Crypto.hmacSHA256(key: signingKey, data: header.encoded() + payload)[..<16]
      header.signature = signature

      return header.encoded() + payload
    } else {
      return packet
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
