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

    @discardableResult
    func pushBaby(_ baby: Baby) async throws -> Baby {
        try await client.request("/babies", method: "POST", body: baby)
    }

    @discardableResult
    func updateBaby(_ baby: Baby) async throws -> Baby {
        try await client.request("/babies/\(baby.id)", method: "PUT", body: baby)
    }

    func deleteBaby(id: UUID) async throws {
        try await client.requestVoid("/babies/\(id)", method: "DELETE")
    }

    // MARK: - Events

    func fetchEvents(babyId: UUID, from: Date?, to: Date?) async throws -> [BabyEvent] {
        var components = URLComponents(string: "/babies/\(babyId)/events")!
        var items: [URLQueryItem] = []
        let fmt = ISO8601DateFormatter()
        if let from { items.append(URLQueryItem(name: "from", value: fmt.string(from: from))) }
        if let to   { items.append(URLQueryItem(name: "to",   value: fmt.string(from: to))) }
        if !items.isEmpty { components.queryItems = items }
        let path = components.url?.absoluteString ?? "/babies/\(babyId)/events"
        return try await client.request(path)
    }

    func syncEvents(babyId: UUID, since: Date) async throws -> [BabyEvent] {
        var components = URLComponents(string: "/babies/\(babyId)/events/sync")!
        components.queryItems = [URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since))]
        let path = components.url?.absoluteString ?? "/babies/\(babyId)/events/sync"
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
        var components = URLComponents(string: "/babies/\(babyId)/growth/sync")!
        components.queryItems = [URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since))]
        let path = components.url?.absoluteString ?? "/babies/\(babyId)/growth/sync"
        return try await client.request(path)
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
