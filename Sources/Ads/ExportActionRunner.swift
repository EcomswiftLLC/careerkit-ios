import UIKit

enum ExportOutcome: Equatable {
    /// The system reported that the share, save or print really completed.
    case completed
    /// The person closed the sheet without finishing.
    case cancelled
    /// The sheet could not be shown or reported an error.
    case failed
}

/// Presents the system share sheet, Files exporter and print dialog, and reports what really happened.
/// Kept as a reference type so the document picker delegate stays alive while it is on screen.
@MainActor
final class ExportActionRunner: NSObject, ObservableObject, UIDocumentPickerDelegate {
    private var pickerCompletion: ((ExportOutcome) -> Void)?

    // MARK: Share

    func share(url: URL, completion: @escaping (ExportOutcome) -> Void) {
        guard let presenter = AdsPresenter.topViewController() else {
            completion(.failed)
            return
        }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        anchorPopover(of: controller, in: presenter)
        controller.completionWithItemsHandler = { _, completed, _, error in
            if completed {
                completion(.completed)
            } else if error != nil {
                completion(.failed)
            } else {
                completion(.cancelled)
            }
        }
        presenter.present(controller, animated: true)
    }

    // MARK: Save to Files

    func saveToFiles(url: URL, completion: @escaping (ExportOutcome) -> Void) {
        guard pickerCompletion == nil, let presenter = AdsPresenter.topViewController() else {
            completion(.failed)
            return
        }
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        picker.delegate = self
        pickerCompletion = completion
        presenter.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finishPicker(.completed)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finishPicker(.cancelled)
    }

    private func finishPicker(_ outcome: ExportOutcome) {
        guard let completion = pickerCompletion else { return }
        pickerCompletion = nil
        completion(outcome)
    }

    // MARK: Print

    func printPDF(data: Data, jobName: String, completion: @escaping (ExportOutcome) -> Void) {
        let printController = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = jobName
        printController.printInfo = info
        printController.printingItem = data

        // Report exactly once, even if the system both returns false and calls the handler.
        var finished = false
        let finish: (ExportOutcome) -> Void = { outcome in
            guard !finished else { return }
            finished = true
            completion(outcome)
        }

        let handler: UIPrintInteractionController.CompletionHandler = { _, completed, error in
            if completed {
                finish(.completed)
            } else if error != nil {
                finish(.failed)
            } else {
                finish(.cancelled)
            }
        }

        let presented: Bool
        if UIDevice.current.userInterfaceIdiom == .pad, let presenter = AdsPresenter.topViewController() {
            let rect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
            presented = printController.present(from: rect, in: presenter.view, animated: true, completionHandler: handler)
        } else {
            presented = printController.present(animated: true, completionHandler: handler)
        }
        if !presented { finish(.failed) }
    }

    // MARK: Helpers

    /// On iPad the share sheet is a popover and needs an anchor. Centre it so it never covers a button edge.
    private func anchorPopover(of controller: UIViewController, in presenter: UIViewController) {
        guard let popover = controller.popoverPresentationController else { return }
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
    }
}
