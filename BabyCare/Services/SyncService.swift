import Foundation

// MARK: - Sync Service Protocol
// Abstracts the backend transport layer.
// Swap implementations without touching EventStore / GrowthStore.

@MainActor
protocol SyncService {
    // MARK: Baby
    func fetchBabies() async throws -> [Baby]
    func pushBaby(_ baby: Baby) async throws
    func updateBaby(_ baby: Baby) async throws
    func deleteBaby(id: UUID) async throws

    // MARK: Events
    func fetchEvents(babyId: UUID, from: Date?, to: Date?) async throws -> [BabyEvent]
    func syncEvents(babyId: UUID, since: Date) async throws -> [BabyEvent]  // includes soft-deletes
    func pushEvent(_ event: BabyEvent) async throws
    func deleteEvent(babyId: UUID, id: UUID) async throws

    // MARK: Growth
    func fetchGrowthRecords(babyId: UUID) async throws -> [GrowthRecord]
    func syncGrowthRecords(babyId: UUID, since: Date) async throws -> [GrowthRecord]
    func pushGrowthRecord(_ record: GrowthRecord) async throws
    func deleteGrowthRecord(babyId: UUID, id: UUID) async throws
}

// MARK: - Sync Errors
enum SyncError: Error, LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case serverError(Int, String)
    case decodingError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:       return "请先登录"
        case .networkUnavailable:     return "网络不可用，数据已保存到本地"
        case .serverError(let c, let m): return "服务器错误（\(c)）：\(m)"
        case .decodingError:          return "数据解析失败"
        case .unknown(let e):         return e.localizedDescription
        }
    }
}
