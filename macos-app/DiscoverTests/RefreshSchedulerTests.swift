import Testing
import Foundation

@testable import Discover

@Suite("Discover — RefreshScheduler (pure helpers)")
struct RefreshSchedulerTests {

    // MARK: - nextFireDelay

    @Test("nextFireDelay returns nil when interval is 0 (Never)")
    func zeroIsNever() {
        #expect(RefreshScheduler.nextFireDelay(intervalMinutes: 0) == nil)
    }

    @Test("nextFireDelay returns nil for negative intervals")
    func negativeIsNever() {
        #expect(RefreshScheduler.nextFireDelay(intervalMinutes: -5) == nil)
    }

    @Test("nextFireDelay returns minutes × 60 for positive intervals")
    func positiveIsMinutesTimes60() {
        #expect(RefreshScheduler.nextFireDelay(intervalMinutes: 1) == 60)
        #expect(RefreshScheduler.nextFireDelay(intervalMinutes: 15) == 900)
        #expect(RefreshScheduler.nextFireDelay(intervalMinutes: 30) == 1800)
        #expect(RefreshScheduler.nextFireDelay(intervalMinutes: 60) == 3600)
    }

    // MARK: - shouldRefresh

    @Test("shouldRefresh is false when auto-refresh is disabled")
    func disabledDoesNotRefresh() {
        #expect(RefreshScheduler.shouldRefresh(intervalMinutes: 0, isOffline: false) == false)
    }

    @Test("shouldRefresh is false when offline")
    func offlineSkips() {
        #expect(RefreshScheduler.shouldRefresh(intervalMinutes: 30, isOffline: true) == false)
    }

    @Test("shouldRefresh is true when enabled and online")
    func enabledOnlineRefreshes() {
        #expect(RefreshScheduler.shouldRefresh(intervalMinutes: 30, isOffline: false) == true)
    }
}
