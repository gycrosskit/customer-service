import Foundation

/// 原生模态的一次性完成条件，取消等待不能调用这些生命周期事件。
final class CustomerServicePresentationCompletion {
    var onClosed: ((Bool) -> Void)?
    private var cancelled = false
    func presentationCompleted(isPresented: Bool) {
        if !isPresented { finish(success: false) }
    }
    func cancelForReset() { cancelled = true }
    func dismissed() { finish(success: !cancelled) }
    private func finish(success: Bool) {
        let completion = onClosed
        onClosed = nil
        completion?(success)
    }
}
