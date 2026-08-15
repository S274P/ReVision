import SwiftUI

/// Visual home-map editor. Rooms and furniture are draggable, resizable tiles on a
/// canvas; doorways connect rooms and become the navigation connections underneath.
///
/// Tap a tile to select it, drag it to move, and drag the yellow bottom-right handle
/// to resize. The bottom toolbar adds rooms, furniture, and doorways; the bar under
/// the title shows actions for whatever is selected.
struct MapEditorView: View {
    @EnvironmentObject private var app: AppState

    enum Selection: Equatable {
        case room(UUID)
        case furniture(UUID)
        case doorway(UUID, UUID)
    }

    @State private var selection: Selection?
    @State private var addingDoorway = false
    @State private var doorwayFirst: UUID?

    @State private var renameTarget: Room?
    @State private var editingDoorway: DoorwayPair?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Theme.background
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { clearSelection() }

                    GridBackground()

                    ForEach($app.layout.rooms) { $room in
                        RoomNode(room: $room,
                                 isSelected: selection == .room(room.id),
                                 isCurrent: room.id == app.layout.currentRoomID,
                                 doorwayMode: addingDoorway,
                                 isDoorwayFirst: doorwayFirst == room.id,
                                 canvas: geo.size,
                                 onTap: { handleRoomTap(room) },
                                 onSelect: { selection = .room(room.id) },
                                 snap: { snapFrame($0, excluding: room.id) })
                    }

                    ForEach($app.layout.furniture) { $item in
                        FurnitureNode(item: $item,
                                      isSelected: selection == .furniture(item.id),
                                      canvas: geo.size,
                                      onSelect: { selection = .furniture(item.id) })
                    }

                    doorwayLayer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Home map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .safeAreaInset(edge: .top) { contextBar }
            .safeAreaInset(edge: .bottom) { toolbar }
            .sheet(item: $renameTarget) { room in
                RenameRoomSheet(name: room.name) { newName in
                    app.layout.renameRoom(room.id, to: newName)
                }
            }
            .sheet(item: $editingDoorway) { pair in
                DoorwayEditSheet(
                    roomAName: pair.a.name,
                    roomBName: pair.b.name,
                    abConnID: app.layout.connection(from: pair.a.id, to: pair.b.id)?.id,
                    baConnID: app.layout.connection(from: pair.b.id, to: pair.a.id)?.id,
                    voice: app.voice,
                    abInstruction: app.layout.connection(from: pair.a.id, to: pair.b.id)?.instruction ?? "",
                    baInstruction: app.layout.connection(from: pair.b.id, to: pair.a.id)?.instruction ?? ""
                ) { ab, ba in
                    app.layout.setInstruction(from: pair.a.id, to: pair.b.id, instruction: ab)
                    app.layout.setInstruction(from: pair.b.id, to: pair.a.id, instruction: ba)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Doorways

    /// Unique unordered room pairs that have at least one connection between them.
    private var doorways: [DoorwayPair] {
        var seen = Set<String>()
        var result: [DoorwayPair] = []
        for conn in app.layout.connections {
            guard let a = app.layout.room(withID: conn.fromRoomID),
                  let b = app.layout.room(withID: conn.toRoomID) else { continue }
            let key = [a.id.uuidString, b.id.uuidString].sorted().joined()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(DoorwayPair(a: a, b: b))
        }
        return result
    }

    /// Draws each doorway as a real opening in the shared wall when two rooms touch,
    /// or a short solid passage when they don't.
    private var doorwayLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(doorways) { d in
                let g = doorGeometry(d.a.frame, d.b.frame)
                let isSel = selection == .doorway(d.a.id, d.b.id)
                if g.adjacent {
                    DoorOpening(geom: g, selected: isSel)
                        .onTapGesture {
                            selection = .doorway(d.a.id, d.b.id)
                            editingDoorway = d
                        }
                } else {
                    Path { p in
                        p.move(to: g.aCenter)
                        p.addLine(to: g.bCenter)
                    }
                    .stroke(Theme.wall.opacity(0.5),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))

                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.accent))
                        .overlay(Circle().stroke(.white, lineWidth: isSel ? 3 : 0))
                        .contentShape(Circle())
                        .onTapGesture {
                            selection = .doorway(d.a.id, d.b.id)
                            editingDoorway = d
                        }
                        .position(g.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Contextual action bar

    private var contextBar: some View {
        Group {
            if addingDoorway {
                hintBar(icon: "door.left.hand.open",
                        text: doorwayFirst == nil
                            ? "Tap the first room to connect."
                            : "Now tap the room to connect it to.")
            } else if let room = selectedRoom {
                HStack(spacing: 10) {
                    Label(room.name, systemImage: "square.dashed")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    smallButton("Rename", "pencil") { renameTarget = room }
                    smallButton(room.id == app.layout.currentRoomID ? "Current" : "Set current",
                                "mappin.and.ellipse") {
                        app.layout.currentRoomID = room.id
                    }
                    smallButton("Delete", "trash", destructive: true) {
                        app.layout.removeRoom(room.id); selection = nil
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial)
            } else if let item = selectedFurniture {
                HStack(spacing: 10) {
                    Label(item.title, systemImage: item.kind.systemImage)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    smallButton("Delete", "trash", destructive: true) {
                        app.layout.removeFurniture(item.id); selection = nil
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial)
            } else if let pair = selectedDoorwayPair {
                HStack(spacing: 10) {
                    Label("\(pair.a.name) ↔ \(pair.b.name)", systemImage: "door.left.hand.open")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    smallButton("Directions", "text.bubble") { editingDoorway = pair }
                    smallButton("Delete", "trash", destructive: true) {
                        app.layout.removeDoorway(pair.a.id, pair.b.id); selection = nil
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial)
            } else {
                hintBar(icon: "hand.tap", text: "Tap a room to select. Drag to move, drag the corner to resize.")
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            toolButton("Add room", "plus.square.on.square", accent: true) {
                addRoom()
            }
            Menu {
                ForEach(FurnitureKind.allCases) { kind in
                    Button {
                        addFurniture(kind)
                    } label: { Label(kind.title, systemImage: kind.systemImage) }
                }
            } label: {
                toolLabel("Furniture", "sofa", accent: false)
            }
            toolButton("Doorway", "door.left.hand.open", accent: addingDoorway) {
                addingDoorway.toggle()
                doorwayFirst = nil
                selection = nil
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Intent

    private func handleRoomTap(_ room: Room) {
        if addingDoorway {
            if let first = doorwayFirst {
                if first != room.id {
                    app.layout.addConnection(from: first, to: room.id,
                                             instruction: "", bidirectional: true)
                    addingDoorway = false
                    doorwayFirst = nil
                    if let a = app.layout.room(withID: first) {
                        editingDoorway = DoorwayPair(a: a, b: room)
                        selection = .doorway(first, room.id)
                    }
                }
            } else {
                doorwayFirst = room.id
            }
        } else {
            selection = .room(room.id)
        }
    }

    private func addRoom() {
        let w = 150.0, h = 120.0
        let frame = MapFrame(x: 200 - w / 2, y: 200 - h / 2, width: w, height: h)
        let room = app.layout.addRoom(named: "Room \(app.layout.rooms.count + 1)", frame: frame)
        selection = .room(room.id)
        renameTarget = room
    }

    private func addFurniture(_ kind: FurnitureKind) {
        app.layout.addFurniture(kind, at: CGPoint(x: 180, y: 240))
        if let added = app.layout.furniture.last {
            selection = .furniture(added.id)
        }
    }

    private func clearSelection() {
        selection = nil
        if addingDoorway { addingDoorway = false; doorwayFirst = nil }
    }

    /// Snaps a room's proposed frame so its edges click to nearby rooms' edges
    /// (touch or align), giving a tidy wall-to-wall floor plan.
    private func snapFrame(_ frame: MapFrame, excluding id: UUID) -> MapFrame {
        let tol = 14.0
        var f = frame
        let others = app.layout.rooms.filter { $0.id != id }

        var bestDX: Double? = nil
        for o in others {
            let oL = o.frame.x, oR = o.frame.x + o.frame.width
            for target in [oR, oL - f.width, oL, oR - f.width] {   // touch right / touch left / align
                let d = target - f.x
                if abs(d) <= tol && (bestDX == nil || abs(d) < abs(bestDX!)) { bestDX = d }
            }
        }
        if let dx = bestDX { f.x += dx }

        var bestDY: Double? = nil
        for o in others {
            let oT = o.frame.y, oB = o.frame.y + o.frame.height
            for target in [oB, oT - f.height, oT, oB - f.height] {
                let d = target - f.y
                if abs(d) <= tol && (bestDY == nil || abs(d) < abs(bestDY!)) { bestDY = d }
            }
        }
        if let dy = bestDY { f.y += dy }

        return f
    }

    // MARK: - Selection lookups

    private var selectedRoom: Room? {
        if case let .room(id) = selection { return app.layout.room(withID: id) }
        return nil
    }
    private var selectedFurniture: FurnitureItem? {
        if case let .furniture(id) = selection { return app.layout.furniture.first { $0.id == id } }
        return nil
    }
    private var selectedDoorwayPair: DoorwayPair? {
        if case let .doorway(a, b) = selection,
           let ra = app.layout.room(withID: a), let rb = app.layout.room(withID: b) {
            return DoorwayPair(a: ra, b: rb)
        }
        return nil
    }

    // MARK: - Small UI helpers

    private func hintBar(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text).font(.system(size: 13))
            Spacer()
        }
        .foregroundStyle(Theme.secondaryText)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func smallButton(_ title: String, _ icon: String,
                             destructive: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(role: destructive ? .destructive : nil, action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .tint(destructive ? Theme.danger : Theme.accent)
    }

    private func toolButton(_ title: String, _ icon: String,
                            accent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolLabel(title, icon, accent: accent) }
    }

    private func toolLabel(_ title: String, _ icon: String, accent: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 20))
            Text(title).font(.system(size: 11, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .foregroundStyle(accent ? Theme.surface : Theme.primaryText)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accent ? Theme.accent : Theme.surface)
        )
    }
}

// MARK: - Doorway pair

private struct DoorwayPair: Identifiable {
    let a: Room
    let b: Room
    var id: String { [a.id.uuidString, b.id.uuidString].sorted().joined() }
}

// MARK: - Room node

private struct RoomNode: View {
    @Binding var room: Room
    let isSelected: Bool
    let isCurrent: Bool
    let doorwayMode: Bool
    let isDoorwayFirst: Bool
    let canvas: CGSize
    let onTap: () -> Void
    let onSelect: () -> Void
    let snap: (MapFrame) -> MapFrame

    @GestureState private var dragT: CGSize = .zero
    @GestureState private var resizeT: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    private let minW: Double = 70
    private let minH: Double = 60
    private let maxSize: Double = 700

    var body: some View {
        let liveW = max(minW, room.frame.width + Double(resizeT.width))
        let liveH = max(minH, room.frame.height + Double(resizeT.height))
        let dx: CGFloat = (doorwayMode || pinch != 1) ? 0 : dragT.width
        let dy: CGFloat = (doorwayMode || pinch != 1) ? 0 : dragT.height

        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(floorColor(for: room))
                .overlay(PlankOverlay().clipShape(RoundedRectangle(cornerRadius: 8)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                )

            VStack(spacing: 3) {
                Text(room.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.surface.opacity(0.82)))
                if isCurrent {
                    Text("Current")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.surface)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.accent))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(6)
            .allowsHitTesting(false)

            if isSelected {
                cornerHandles
                resizeHandle
            }
        }
        .frame(width: CGFloat(liveW), height: CGFloat(liveH))
        .scaleEffect(pinch, anchor: .topLeading)
        .contentShape(Rectangle())
        .gesture(moveGesture)
        .simultaneousGesture(pinchGesture)
        .position(x: CGFloat(room.frame.x) + CGFloat(liveW) / 2 + dx,
                  y: CGFloat(room.frame.y) + CGFloat(liveH) / 2 + dy)
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { v, s, _ in s = v.magnification }
            .onEnded { v in
                var f = room.frame
                f.width = min(max(minW, f.width * Double(v.magnification)), maxSize)
                f.height = min(max(minH, f.height * Double(v.magnification)), maxSize)
                room.frame = f
                onSelect()
            }
    }

    private var borderColor: Color {
        if isDoorwayFirst { return Theme.safe }
        return isSelected ? Theme.accent : Theme.wall
    }
    private var borderWidth: CGFloat { (isSelected || isDoorwayFirst) ? 3 : 2 }

    private var cornerHandles: some View {
        GeometryReader { g in
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 10, height: 10)
                    .position(x: (i % 2 == 0) ? 0 : g.size.width,
                              y: (i < 2) ? 0 : g.size.height)
            }
        }
        .allowsHitTesting(false)
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: 30, height: 30)
            .overlay(Image(systemName: "arrow.down.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black))
            .offset(x: -3, y: -3)
            .highPriorityGesture(
                DragGesture()
                    .updating($resizeT) { v, s, _ in s = v.translation }
                    .onEnded { v in
                        var f = room.frame
                        f.width = min(max(minW, f.width + Double(v.translation.width)), maxSize)
                        f.height = min(max(minH, f.height + Double(v.translation.height)), maxSize)
                        room.frame = f
                    }
            )
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragT) { v, s, _ in s = v.translation }
            .onEnded { v in
                let moved = abs(v.translation.width) + abs(v.translation.height) > 6
                if moved && !doorwayMode {
                    var f = room.frame
                    f.x = min(max(0, f.x + Double(v.translation.width)),
                              max(0, Double(canvas.width) - f.width))
                    f.y = min(max(0, f.y + Double(v.translation.height)),
                              max(0, Double(canvas.height) - f.height))
                    room.frame = snap(f)
                    onSelect()
                } else {
                    onTap()
                }
            }
    }
}

// MARK: - Furniture node

private struct FurnitureNode: View {
    @Binding var item: FurnitureItem
    let isSelected: Bool
    let canvas: CGSize
    let onSelect: () -> Void

    @GestureState private var dragT: CGSize = .zero
    @GestureState private var resizeT: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    private let minSize: Double = 26
    private let maxSize: Double = 400

    var body: some View {
        let liveW = max(minSize, item.frame.width + Double(resizeT.width))
        let liveH = max(minSize, item.frame.height + Double(resizeT.height))

        let style = furnitureStyle(item.kind)
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 9)
                .fill(style.fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(isSelected ? Theme.accent : Color.black.opacity(0.10),
                                      lineWidth: isSelected ? 3 : 1)
                )

            Image(systemName: item.kind.systemImage)
                .font(.system(size: min(liveW, liveH) >= 40 ? 20 : 15, weight: .semibold))
                .foregroundStyle(style.icon)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            if isSelected {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black))
                    .offset(x: -2, y: -2)
                    .highPriorityGesture(
                        DragGesture()
                            .updating($resizeT) { v, s, _ in s = v.translation }
                            .onEnded { v in
                                var f = item.frame
                                f.width = min(max(minSize, f.width + Double(v.translation.width)), maxSize)
                                f.height = min(max(minSize, f.height + Double(v.translation.height)), maxSize)
                                item.frame = f
                            }
                    )
            }
        }
        .frame(width: CGFloat(liveW), height: CGFloat(liveH))
        .scaleEffect(pinch, anchor: .topLeading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragT) { v, s, _ in s = v.translation }
                .onEnded { v in
                    let moved = abs(v.translation.width) + abs(v.translation.height) > 6
                    if moved {
                        var f = item.frame
                        f.x = min(max(0, f.x + Double(v.translation.width)),
                                  max(0, Double(canvas.width) - f.width))
                        f.y = min(max(0, f.y + Double(v.translation.height)),
                                  max(0, Double(canvas.height) - f.height))
                        item.frame = f
                    }
                    onSelect()
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .updating($pinch) { v, s, _ in s = v.magnification }
                .onEnded { v in
                    var f = item.frame
                    f.width = min(max(minSize, f.width * Double(v.magnification)), maxSize)
                    f.height = min(max(minSize, f.height * Double(v.magnification)), maxSize)
                    item.frame = f
                    onSelect()
                }
        )
        .position(x: CGFloat(item.frame.x) + CGFloat(liveW) / 2 + (pinch == 1 ? dragT.width : 0),
                  y: CGFloat(item.frame.y) + CGFloat(liveH) / 2 + (pinch == 1 ? dragT.height : 0))
    }
}

// MARK: - Doorway geometry

/// Where and how to draw a doorway between two rooms: an opening in the shared
/// wall if they touch, otherwise a short passage between their centers.
private struct DoorGeom {
    var adjacent: Bool
    var center: CGPoint
    var vertical: Bool     // true = shared wall is vertical (opening runs up/down)
    var span: CGFloat      // length of the opening
    var aCenter: CGPoint
    var bCenter: CGPoint
}

/// Works out the shared wall (if any) between two room rectangles.
private func doorGeometry(_ a: MapFrame, _ b: MapFrame) -> DoorGeom {
    let aL = a.x, aR = a.x + a.width, aT = a.y, aB = a.y + a.height
    let bL = b.x, bR = b.x + b.width, bT = b.y, bB = b.y + b.height
    let tol = 22.0
    let doorW = 34.0

    let yOverlap = min(aB, bB) - max(aT, bT)
    let xOverlap = min(aR, bR) - max(aL, bL)

    // Vertical shared wall (rooms side by side)
    if abs(aR - bL) <= tol, yOverlap > 10 {
        let wallX = (aR + bL) / 2
        let midY = (max(aT, bT) + min(aB, bB)) / 2
        return DoorGeom(adjacent: true, center: CGPoint(x: wallX, y: midY),
                        vertical: true, span: CGFloat(min(yOverlap, doorW)),
                        aCenter: a.center, bCenter: b.center)
    }
    if abs(bR - aL) <= tol, yOverlap > 10 {
        let wallX = (bR + aL) / 2
        let midY = (max(aT, bT) + min(aB, bB)) / 2
        return DoorGeom(adjacent: true, center: CGPoint(x: wallX, y: midY),
                        vertical: true, span: CGFloat(min(yOverlap, doorW)),
                        aCenter: a.center, bCenter: b.center)
    }
    // Horizontal shared wall (rooms stacked)
    if abs(aB - bT) <= tol, xOverlap > 10 {
        let wallY = (aB + bT) / 2
        let midX = (max(aL, bL) + min(aR, bR)) / 2
        return DoorGeom(adjacent: true, center: CGPoint(x: midX, y: wallY),
                        vertical: false, span: CGFloat(min(xOverlap, doorW)),
                        aCenter: a.center, bCenter: b.center)
    }
    if abs(bB - aT) <= tol, xOverlap > 10 {
        let wallY = (bB + aT) / 2
        let midX = (max(aL, bL) + min(aR, bR)) / 2
        return DoorGeom(adjacent: true, center: CGPoint(x: midX, y: wallY),
                        vertical: false, span: CGFloat(min(xOverlap, doorW)),
                        aCenter: a.center, bCenter: b.center)
    }
    // Not touching — passage between centers.
    return DoorGeom(adjacent: false,
                    center: CGPoint(x: (a.center.x + b.center.x) / 2,
                                    y: (a.center.y + b.center.y) / 2),
                    vertical: true, span: CGFloat(doorW),
                    aCenter: a.center, bCenter: b.center)
}

/// A doorway rendered as a gap cut into the shared wall, with a door-swing arc.
private struct DoorOpening: View {
    let geom: DoorGeom
    let selected: Bool

    var body: some View {
        let thickness: CGFloat = 14
        let w = geom.vertical ? thickness : geom.span
        let h = geom.vertical ? geom.span : thickness
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.surface)                       // the opening (threshold)
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(selected ? Theme.accent : Theme.wall.opacity(0.55),
                              lineWidth: selected ? 3 : 1.5)
            DoorSwing(vertical: geom.vertical)
                .stroke(Theme.wall.opacity(0.6), lineWidth: 1.5)
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        .position(geom.center)
    }
}

/// A quarter-circle door-swing arc drawn inside the opening's frame.
private struct DoorSwing: Shape {
    let vertical: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = vertical ? rect.height : rect.width
        if vertical {
            let hinge = CGPoint(x: rect.midX, y: rect.maxY)
            p.move(to: hinge)
            p.addArc(center: hinge, radius: r,
                     startAngle: .degrees(-90), endAngle: .degrees(-180), clockwise: true)
        } else {
            let hinge = CGPoint(x: rect.minX, y: rect.midY)
            p.move(to: hinge)
            p.addArc(center: hinge, radius: r,
                     startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }
        return p
    }
}

// MARK: - Map styling helpers

/// A stable warm floor tone per room, so different rooms read like different floors.
private func floorColor(for room: Room) -> Color {
    let sum = room.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return Theme.floors[sum % Theme.floors.count]
}

/// Fill + icon color for each furniture kind — warm, material-like tones.
private func furnitureStyle(_ kind: FurnitureKind) -> (fill: Color, icon: Color) {
    switch kind {
    case .sofa, .chair:
        return (Color(red: 0.553, green: 0.627, blue: 0.478), .white)          // sage upholstery
    case .bed:
        return (Color(red: 0.914, green: 0.855, blue: 0.741),
                Color(red: 0.36, green: 0.30, blue: 0.24))                       // linen
    case .table, .counter:
        return (Color(red: 0.780, green: 0.608, blue: 0.420), .white)          // wood
    case .toilet, .sink:
        return (Color(red: 0.749, green: 0.796, blue: 0.788),
                Color(red: 0.28, green: 0.33, blue: 0.33))                       // porcelain
    case .tv:
        return (Color(red: 0.412, green: 0.416, blue: 0.427), .white)          // slate
    case .rug:
        return (Color(red: 0.851, green: 0.663, blue: 0.510),
                Color(red: 0.40, green: 0.27, blue: 0.19))                       // terracotta rug
    case .plant:
        return (Color(red: 0.498, green: 0.639, blue: 0.416), .white)          // greenery
    case .other:
        return (Color(red: 0.769, green: 0.718, blue: 0.635),
                Color(red: 0.33, green: 0.29, blue: 0.24))                       // warm neutral
    }
}

/// Faint horizontal lines that give a room's floor a subtle wood-plank texture.
private struct PlankOverlay: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                let planks = 4
                for i in 1..<planks {
                    let y = g.size.height * CGFloat(i) / CGFloat(planks)
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: g.size.width, y: y))
                }
            }
            .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Grid background

private struct GridBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 20
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step
            }
            ctx.stroke(path, with: .color(Color.black.opacity(0.05)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Sheets

private struct RenameRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onSave: (String) -> Void

    init(name: String, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: name)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Room name", text: $text)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("Rename room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty { onSave(name) }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(180)])
    }
}

private struct DoorwayEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let roomAName: String
    let roomBName: String
    let abConnID: UUID?
    let baConnID: UUID?
    @ObservedObject var voice: VoiceLibrary
    @State private var ab: String
    @State private var ba: String
    let onSave: (String, String) -> Void

    init(roomAName: String, roomBName: String,
         abConnID: UUID?, baConnID: UUID?,
         voice: VoiceLibrary,
         abInstruction: String, baInstruction: String,
         onSave: @escaping (String, String) -> Void) {
        self.roomAName = roomAName
        self.roomBName = roomBName
        self.abConnID = abConnID
        self.baConnID = baConnID
        self.voice = voice
        _ab = State(initialValue: abInstruction)
        _ba = State(initialValue: baInstruction)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Going \(roomAName) \u{2192} \(roomBName)") {
                    TextField("Spoken instruction", text: $ab, axis: .vertical)
                    if let abConnID { recordRow(key: "dw:\(abConnID.uuidString)") }
                }
                Section("Going \(roomBName) \u{2192} \(roomAName)") {
                    TextField("Spoken instruction", text: $ba, axis: .vertical)
                    if let baConnID { recordRow(key: "dw:\(baConnID.uuidString)") }
                }
            }
            .navigationTitle("Doorway")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(ab, ba); dismiss() }
                }
            }
            .onDisappear {
                if voice.isRecording { voice.stopRecording() }
                voice.stopPreview()
            }
        }
    }

    @ViewBuilder
    private func recordRow(key: String) -> some View {
        let recorded = voice.hasRecording(for: key)
        let isRec = voice.recordingKey == key
        HStack(spacing: 16) {
            if isRec {
                Button { voice.stopRecording() } label: {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .foregroundStyle(Theme.danger)
                }
            } else {
                Button { voice.startRecording(for: key) } label: {
                    Label(recorded ? "Re-record in my voice" : "Record in my voice",
                          systemImage: "mic.circle.fill")
                }
                if recorded {
                    Button { voice.preview(key: key) } label: {
                        Image(systemName: "play.circle")
                    }
                    Button(role: .destructive) { voice.delete(key: key) } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            Spacer()
            if recorded && !isRec {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.safe)
            }
        }
        .buttonStyle(.borderless)
        .font(.subheadline)
    }
}
