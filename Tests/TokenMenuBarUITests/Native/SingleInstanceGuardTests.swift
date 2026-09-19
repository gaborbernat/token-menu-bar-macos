import AppKit
import Testing
import TokenMenuBarTestSupport

@testable import TokenMenuBarCore
@testable import TokenMenuBarUI

@Test(arguments: [
  (arguments: ["TokenMenuBar"], environment: [String: String](), yields: true),
  (arguments: ["TokenMenuBar", LaunchPolicy.relaunchedArgument], environment: [:], yields: false),
  (arguments: ["TokenMenuBar", LaunchPolicy.verificationArgument], environment: [:], yields: false),
  (arguments: ["TokenMenuBar"], environment: [LaunchPolicy.verificationEnvironmentKey: "1"], yields: false),
])
func launchPolicyYieldsToARunningInstanceOnlyForPlainLaunches(
  arguments: [String], environment: [String: String], yields: Bool
) {
  #expect(LaunchPolicy(arguments: arguments, environment: environment).yieldsToRunningInstance == yields)
}

@Test @MainActor func singleInstanceGuardActivatesTheOtherInstanceAndAsksThisOneToExit() {
  prepareTestApp()
  var lookups: [String] = []

  let handedOff = SingleInstanceGuard.handOff(
    policy: LaunchPolicy(arguments: ["TokenMenuBar"], environment: [:]), bundleIdentifier: "dev.tox.token-menu-bar",
    currentProcessIdentifier: 0,
    runningApplications: {
      lookups.append($0)
      return [.current]
    })

  #expect(handedOff)
  #expect(lookups == ["dev.tox.token-menu-bar"])
}

@Test @MainActor func singleInstanceGuardIgnoresItself() {
  let handedOff = SingleInstanceGuard.handOff(
    policy: LaunchPolicy(arguments: ["TokenMenuBar"], environment: [:]), bundleIdentifier: "dev.tox.token-menu-bar",
    runningApplications: { _ in [.current] })

  #expect(!handedOff)
}

@Test @MainActor func singleInstanceGuardLeavesUnbundledAndRelaunchedProcessesAlone() {
  var lookups = 0
  let find: (String) -> [NSRunningApplication] = { _ in
    lookups += 1
    return [.current]
  }

  #expect(
    !SingleInstanceGuard.handOff(
      policy: LaunchPolicy(arguments: ["TokenMenuBar"], environment: [:]), bundleIdentifier: nil,
      currentProcessIdentifier: 0, runningApplications: find))
  #expect(
    !SingleInstanceGuard.handOff(
      policy: LaunchPolicy(arguments: ["TokenMenuBar", LaunchPolicy.relaunchedArgument], environment: [:]),
      bundleIdentifier: "dev.tox.token-menu-bar", currentProcessIdentifier: 0, runningApplications: find))
  #expect(lookups == 0)
}

// A sandboxed relaunch arrives without `--relaunched`, so only the handshake tells the replacement to stay.
@Test @MainActor func singleInstanceGuardLetsTheReplacementOfASandboxedRelaunchStart() {
  let handedOff = SingleInstanceGuard.handOff(
    policy: LaunchPolicy(arguments: ["TokenMenuBar"], environment: [:]),
    replacing: NSRunningApplication.current.processIdentifier, bundleIdentifier: "dev.tox.token-menu-bar",
    currentProcessIdentifier: 0, runningApplications: { _ in [.current] })

  #expect(!handedOff)
}

@Test @MainActor func singleInstanceGuardConsultsTheRunningApplicationList() {
  let policy = LaunchPolicy(arguments: ["TokenMenuBar"], environment: [:])

  #expect(!SingleInstanceGuard.handOff(policy: policy, bundleIdentifier: "dev.tox.token-menu-bar.absent"))
}
