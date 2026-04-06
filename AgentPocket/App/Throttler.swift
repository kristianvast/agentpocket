import Foundation

@MainActor
final class Throttler {
    private var workItem: DispatchWorkItem?
    private var lastRun: Date = .distantPast
    private let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func throttle(_ block: @escaping @MainActor () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem { @MainActor in
            block()
        }
        self.workItem = item
        let elapsed = Date().timeIntervalSince(lastRun)
        let needed = elapsed >= delay ? 0 : delay - elapsed
        DispatchQueue.main.asyncAfter(deadline: .now() + needed) { [weak self] in
            guard let self, self.workItem === item else { return }
            self.lastRun = Date()
            item.perform()
        }
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
