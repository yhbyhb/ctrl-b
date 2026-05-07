import Cocoa

func presentUpdateResultAsAlert(_ result: UpdateResult, onDownload: @escaping () -> Void) {
    let localized = { (key: String) in NSLocalizedString(key, bundle: .module, comment: "") }
    let alert = NSAlert()
    alert.alertStyle = .informational
    switch result {
    case .upToDate:
        alert.messageText = localized("update.up_to_date.title")
        alert.informativeText = localized("update.up_to_date.message")
        alert.addButton(withTitle: localized("update.button.ok"))
        alert.runModal()
    case .available(let version):
        alert.messageText = localized("update.available.title")
        alert.informativeText = String(format: localized("update.available.message"), version)
        alert.addButton(withTitle: localized("update.button.download"))
        alert.addButton(withTitle: localized("update.button.cancel"))
        if alert.runModal() == .alertFirstButtonReturn {
            onDownload()
        }
    case .unknown:
        alert.messageText = localized("update.unknown.title")
        alert.informativeText = localized("update.unknown.message")
        alert.addButton(withTitle: localized("update.button.ok"))
        alert.runModal()
    }
}
