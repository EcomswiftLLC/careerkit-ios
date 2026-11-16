import XCTest
@testable import CareerKit

/// The live preview never runs more than one render at a time and never keeps more than one waiting.
final class EditorPreviewQueueTests: XCTestCase {
    func testFirstRequestStartsImmediately() {
        var queue = PreviewRenderQueue()
        XCTAssertEqual(queue.submit(1), .startNow(1))
        XCTAssertTrue(queue.isBusy)
        XCTAssertEqual(queue.complete(1), PreviewRenderQueue.Completion(publish: true, next: nil))
        XCTAssertFalse(queue.isBusy)
    }

    func testBurstWhileRenderingCollapsesToTheLatest() {
        var queue = PreviewRenderQueue()
        XCTAssertEqual(queue.submit(1), .startNow(1))
        XCTAssertEqual(queue.submit(2), .queued(replaced: nil))
        XCTAssertEqual(queue.submit(3), .queued(replaced: 2))
        XCTAssertEqual(queue.submit(4), .queued(replaced: 3))
        XCTAssertEqual(queue.inFlight, 1)
        XCTAssertEqual(queue.pending, 4)

        // The running render's result is still newer than what is on screen, so it is shown, then 4 starts.
        XCTAssertEqual(queue.complete(1), PreviewRenderQueue.Completion(publish: true, next: 4))
        XCTAssertEqual(queue.inFlight, 4)
        XCTAssertNil(queue.pending)
        XCTAssertEqual(queue.complete(4), PreviewRenderQueue.Completion(publish: true, next: nil))
        XCTAssertEqual(queue.lastPublished, 4)
        XCTAssertFalse(queue.isBusy)
    }

    func testNeverMoreThanOneInFlightAndOnePending() {
        var queue = PreviewRenderQueue()
        var started: [Int] = []
        for generation in 1...50 {
            if case .startNow(let value) = queue.submit(generation) { started.append(value) }
            XCTAssertNotNil(queue.inFlight)
            if generation > 1 { XCTAssertEqual(queue.pending, generation) }
        }
        XCTAssertEqual(started, [1])
        let outcome = queue.complete(1)
        XCTAssertEqual(outcome.next, 50, "only the newest waiting request runs")
        XCTAssertEqual(queue.complete(50).next, nil)
    }

    func testStaleCompletionIsIgnored() {
        var queue = PreviewRenderQueue()
        _ = queue.submit(1)
        XCTAssertEqual(queue.complete(7), PreviewRenderQueue.Completion(publish: false, next: nil))
        XCTAssertEqual(queue.inFlight, 1)
    }

    func testCancelDropsPendingAndTheRunningResult() {
        var queue = PreviewRenderQueue()
        _ = queue.submit(1)
        _ = queue.submit(2)
        queue.cancelAll(through: 2)
        XCTAssertNil(queue.pending)
        XCTAssertEqual(queue.inFlight, 1, "a synchronous render cannot be stopped, it is only ignored")
        XCTAssertEqual(queue.complete(1), PreviewRenderQueue.Completion(publish: false, next: nil))
        XCTAssertFalse(queue.isBusy)
    }

    func testRequestAfterCancelWaitsForTheIgnoredRender() {
        var queue = PreviewRenderQueue()
        _ = queue.submit(1)
        queue.cancelAll(through: 1)
        XCTAssertEqual(queue.submit(2), .queued(replaced: nil), "still only one render at a time")
        XCTAssertEqual(queue.complete(1), PreviewRenderQueue.Completion(publish: false, next: 2))
        XCTAssertEqual(queue.complete(2), PreviewRenderQueue.Completion(publish: true, next: nil))
    }
}

/// End to end on the main actor: a burst of schedules renders far fewer times than it was asked to.
final class EditorRenderCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

@MainActor
final class EditorLivePreviewRendererTests: XCTestCase {
    typealias Counter = EditorRenderCounter

    private func work(_ counter: Counter, delay: TimeInterval) -> RenderWork {
        return {
            counter.increment()
            Thread.sleep(forTimeInterval: delay)
            let resume = Resume(title: "Queue", templateID: TemplateLibrary.defaultTemplateID, sections: [])
            return DocumentRenderer.render(resume, template: EditorRender.template(id: resume.templateID))
        }
    }

    func testBurstOfImmediateSchedulesRendersAtMostTwice() async throws {
        let renderer = LivePreviewRenderer()
        let counter = Counter()
        for _ in 0..<20 {
            renderer.schedule(delay: 0, work: work(counter, delay: 0.2))
        }
        XCTAssertTrue(renderer.isRendering)
        for _ in 0..<60 where renderer.isRendering {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertFalse(renderer.isRendering)
        XCTAssertNotNil(renderer.document)
        XCTAssertEqual(counter.count, 2, "the first request plus the newest waiting one")
    }

    func testDebounceCollapsesRequestsInsideTheWindow() async throws {
        let renderer = LivePreviewRenderer()
        let counter = Counter()
        for _ in 0..<10 {
            renderer.schedule(work: work(counter, delay: 0))
        }
        XCTAssertTrue(renderer.isRendering, "waiting for the debounce counts as busy")
        for _ in 0..<60 where renderer.isRendering {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(counter.count, 1)
        XCTAssertNotNil(renderer.document)
    }

    func testCancelKeepsTheOldDocumentAndStopsWaiting() async throws {
        let renderer = LivePreviewRenderer()
        let counter = Counter()
        renderer.schedule(work: work(counter, delay: 0))
        renderer.cancel()
        XCTAssertFalse(renderer.isRendering)
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(counter.count, 0)
        XCTAssertNil(renderer.document)
    }
}
