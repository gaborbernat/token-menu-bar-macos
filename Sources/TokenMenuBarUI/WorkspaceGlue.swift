import AppKit

// Launching a replacement instance asks LaunchServices to open a bundle, which a test cannot do without opening a
// real app, so this one call lives here and the coverage gate skips it.
extension LiveDependencies {
  struct RuntimeActions {
    let openURL: @MainActor (URL) -> Void
    let copy: @MainActor (String) -> Void
    let reveal: @MainActor (URL) -> Void
    let terminate: @MainActor () -> Void
  }

  @MainActor static func resolvedWorkspaceOpen(_ open: WorkspaceOpen?) -> WorkspaceOpen {
    open ?? workspaceLauncher
  }

  @MainActor static func windowPresentation(enabled: Bool) -> @MainActor (NSWindow, Any?) -> Void {
    enabled ? presentWindow : ignoreWindowPresentation
  }

  @MainActor static func runtimeActions(verification: Bool) -> RuntimeActions {
    verification
      ? RuntimeActions(openURL: ignoreURL, copy: ignoreText, reveal: ignoreURL, terminate: ignore)
      : RuntimeActions(openURL: openURL, copy: copyText, reveal: reveal, terminate: terminate)
  }

  @MainActor
  public static func workspaceLauncher(
    _ url: URL, _ configuration: NSWorkspace.OpenConfiguration, _ done: @escaping @Sendable () -> Void
  ) {
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in done() }
  }

  @MainActor private static func openURL(_ url: URL) { NSWorkspace.shared.open(url) }
  @MainActor private static func copyText(_ text: String) { copy(text, to: .general) }
  @MainActor private static func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
  @MainActor private static func terminate() { NSApplication.shared.terminate(nil) }
  @MainActor static func presentWindow(_ window: NSWindow, sender: Any?) { window.makeKeyAndOrderFront(sender) }
  @MainActor private static func ignoreWindowPresentation(_: NSWindow, _: Any?) {}
  private static func ignoreURL(_: URL) {}
  private static func ignoreText(_: String) {}
  private static func ignore() {}
}
