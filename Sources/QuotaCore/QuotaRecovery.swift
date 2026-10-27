import Foundation

/// The earliest reported 5-hour or weekly reset across the selected accounts.
public enum QuotaRecovery {
    public static func nextReset(in quotas: [AccountQuota]) -> Date? {
        quotas.filter { !$0.account.disabled && $0.issue == nil }.compactMap { quota -> Date? in
            quota.windows.filter { $0.standardPeriod != nil }.compactMap(\.resetsAt).min()
        }.min()
    }
}
