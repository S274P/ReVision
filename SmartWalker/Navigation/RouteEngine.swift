import Foundation

/// Computes a route between two rooms over the house graph.
///
/// Connections are unweighted, so a breadth-first search gives the shortest path
/// (fewest rooms to pass through). Each hop is turned into a `RouteStep` carrying the
/// caretaker's spoken instruction for that connection.
enum RouteEngine {

    /// Returns the ordered list of steps from `origin` to `destination`,
    /// or `nil` if no path exists. Returns an empty array if origin == destination.
    static func route(in layout: HouseLayout,
                      from origin: UUID,
                      to destination: UUID) -> [RouteStep]? {
        guard origin != destination else { return [] }
        guard layout.room(withID: origin) != nil,
              layout.room(withID: destination) != nil else { return nil }

        // BFS, remembering how we reached each node so we can reconstruct the path.
        var visited: Set<UUID> = [origin]
        var queue: [UUID] = [origin]
        var cameFrom: [UUID: UUID] = [:]   // node -> previous node

        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == destination { break }
            for next in layout.neighbors(of: current) where !visited.contains(next) {
                visited.insert(next)
                cameFrom[next] = current
                queue.append(next)
            }
        }

        guard visited.contains(destination) else { return nil } // unreachable

        // Reconstruct room path from destination back to origin.
        var path: [UUID] = [destination]
        var node = destination
        while let prev = cameFrom[node] {
            path.append(prev)
            node = prev
        }
        path.reverse()

        // Turn consecutive room pairs into steps.
        var steps: [RouteStep] = []
        for i in 0..<(path.count - 1) {
            let fromID = path[i]
            let toID = path[i + 1]
            guard let fromRoom = layout.room(withID: fromID),
                  let toRoom = layout.room(withID: toID) else { continue }
            let connection = layout.connection(from: fromID, to: toID)
            let instruction = connection?.instruction.isEmpty == false
                ? connection!.instruction
                : "Move forward carefully toward the \(toRoom.name.lowercased())."
            steps.append(RouteStep(fromRoom: fromRoom,
                                   toRoom: toRoom,
                                   instruction: instruction,
                                   connectionID: connection?.id))
        }
        return steps
    }
}
