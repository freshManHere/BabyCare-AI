import Foundation

// MARK: - Remote Sync Service
// Implements SyncService using the self-hosted backend via APIClient.

@MainActor
final class RemoteSyncService: SyncService {

    private let client: APIClient

    init() {
        self.client = APIClient.shared
    }

    // MARK: - Baby

    func fetchBabies() async throws -> [Baby] {
        try await client.request("/babies")
    }

    func pushBaby(_ baby: Baby) async throws {
        let _: Baby = try await client.request("/babies", method: "POST", body: baby)
    }

    func deleteBaby(id: UUID) async throws {
        try await client.requestVoid("/babies/\(id)", method: "DELETE")
    }

    // MARK: - Events

    func fetchEvents(babyId: UUID, from: Date?, to: Date?) async throws -> [BabyEvent] {
        var path = "/babies/\(babyId)/events"
        var params: [String] = []
        let fmt = ISO8601DateFormatter()
        if let from { params.append("from=\(fmt.string(from: from))") }
        if let to   { params.append("to=\(fmt.string(from: to))") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await client.request(path)
    }

    func syncEvents(babyId: UUID, since: Date) async throws -> [BabyEvent] {
        let fmt = ISO8601DateFormatter()
        let path = "/babies/\(babyId)/events/sync?since=\(fmt.string(from: since))"
        return try await client.request(path)
    }

    func pushEvent(_ event: BabyEvent) async throws {
        let _: BabyEvent = try await client.request(
            "/babies/\(event.babyId)/events", method: "POST", body: event
        )
    }

    func deleteEvent(babyId: UUID, id: UUID) async throws {
        try await client.requestVoid("/babies/\(babyId)/events/\(id)", method: "DELETE")
    }

    // MARK: - Growth

    func fetchGrowthRecords(babyId: UUID) async throws -> [GrowthRecord] {
        try await client.request("/babies/\(babyId)/growth")
    }

    func syncGrowthRecords(babyId: UUID, since: Date) async throws -> [GrowthRecord] {
        let fmt = ISO8601DateFormatter()
        return try await client.request("/babies/\(babyId)/growth/sync?since=\(fmt.string(from: since))")
    }

    func pushGrowthRecord(_ record: GrowthRecord) async throws {
        let _: GrowthRecord = try await client.request(
            "/babies/\(record.babyId)/growth", method: "POST", body: record
        )
    }

    func deleteGrowthRecord(babyId: UUID, id: UUID) async throws {
        try await client.requestVoid("/babies/\(babyId)/growth/\(id)", method: "DELETE")
    }
}
