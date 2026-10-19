import Carbon

/// A system-wide shortcut through Carbon's hot key API, which needs no Accessibility permission.
@MainActor
final class HotKey {
    fileprivate let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    /// `keyCode` is a `kVK_` constant; `modifiers` combines Carbon's `cmdKey`, `optionKey`, `controlKey`.
    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyPressed, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)
        // 'POMO'
        let id = EventHotKeyID(signature: 0x504F_4D4F, id: 1)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKey)
    }
}

/// This is the app's only hot key, so any press is ours.
private func hotKeyPressed(_ call: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in hotKey.action() }
    return noErr
}
