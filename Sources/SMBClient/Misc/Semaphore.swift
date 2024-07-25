import Foundation

public actor Semaphore {
  private var value: Int
  private var waiters: [CheckedContinuation<Void, Never>] = []

  public init(value: Int = 0) {
    self.value = value
  }

  public func wait() async {
    value -= 1
    guard value < 0 else { return }
    await withCheckedContinuation {
      waiters.append($0)
    }
  }

  public func signal() {
    value += 1
    guard !waiters.isEmpty else { return }
    waiters.removeFirst().resume()
  }
}
