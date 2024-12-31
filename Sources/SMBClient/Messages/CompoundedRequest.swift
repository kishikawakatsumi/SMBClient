import Foundation

struct CompoundedRequest<each Request: Message.Request> {
  let requests: (repeat each Request)

  var count: Int {
    var count = 0
    for _ in repeat each requests {
      count += 1
    }
    return count
  }

  init(requests: repeat each Request) {
    self.requests = (repeat each requests)
  }

  func encoded() -> Data {
    var packet = Data()
    
    var index = 0
    for request in repeat each requests {
      let data = request.encoded()
      let alignment = Data(count: 8 - data.count % 8)
      if index < count - 1 {
        let body = data + alignment
        var header = Header(data: body[..<64])
        let payload = data[64...]

        header.nextCommand = UInt32(body.count)

//        packet += sign(header.encoded() + payload + alignment)
      } else {
//        packet += sign(data + alignment)
      }

      index += 1
    }

    return packet
  }
}
