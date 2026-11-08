extends Control
## First networking milestone: a host and 4 colored circles controlled by phones.
## Input relay is authoritative only for room membership; Godot owns positions.

const SPEED := 220.0
const COLORS := [Color("ffbd69"), Color("72d6ba"), Color("8eafff"), Color("ff8ab0")]
const STARTS := [Vector2(170, 260), Vector2(310, 260), Vector2(450, 260), Vector2(590, 260)]

var peer := WebSocketPeer.new()
var connected := false
var room_code := ""
var players: Dictionary = {} # player id -> {number, position, input, action}
var connection_status: Label
var room_label: Label
var endpoint: LineEdit
var connect_button: Button
var info_label: Label

func _ready() -> void:
    var ui := VBoxContainer.new()
    ui.position = Vector2(22, 16)
    ui.add_theme_constant_override("separation", 8)
    add_child(ui)

    var heading := Label.new()
    heading.text = "PandeMOOnium - Phone Controller Test"
    heading.add_theme_font_size_override("font_size", 24)
    ui.add_child(heading)

    var network_row := HBoxContainer.new()
    ui.add_child(network_row)
    endpoint = LineEdit.new()
    endpoint.custom_minimum_size = Vector2(290, 0)
    endpoint.text = "ws://127.0.0.1:3000/ws"
    network_row.add_child(endpoint)
    connect_button = Button.new()
    connect_button.text = "Create room"
    connect_button.pressed.connect(_connect_to_server)
    network_row.add_child(connect_button)

    connection_status = Label.new()
    connection_status.text = "Not connected. Start Node server, then click Create room."
    ui.add_child(connection_status)
    room_label = Label.new()
    room_label.add_theme_font_size_override("font_size", 25)
    room_label.text = "ROOM: ------"
    ui.add_child(room_label)
    info_label = Label.new()
    info_label.text = "Open http://YOUR-LAPTOP-IP:3000 on each phone, then enter the room code."
    ui.add_child(info_label)
    set_process(true)

func _connect_to_server() -> void:
    if peer.get_ready_state() == WebSocketPeer.STATE_OPEN or peer.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
        peer.close()
    peer = WebSocketPeer.new()
    var err := peer.connect_to_url(endpoint.text.strip_edges())
    if err != OK:
        connection_status.text = "Connection failed: %s" % error_string(err)
        return
    connected = false
    connect_button.disabled = true
    connection_status.text = "Connecting..."

func _process(delta: float) -> void:
    peer.poll()
    var state := peer.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        if not connected:
            connected = true
            connection_status.text = "Connected. Creating room..."
            _send({"type": "create_room"})
        while peer.get_available_packet_count() > 0:
            var raw := peer.get_packet().get_string_from_utf8()
            var message = JSON.parse_string(raw)
            if typeof(message) == TYPE_DICTIONARY:
                _on_message(message)
    elif state == WebSocketPeer.STATE_CLOSED and connected:
        connected = false
        room_code = ""
        players.clear()
        room_label.text = "ROOM: ------"
        connection_status.text = "Disconnected. Click Create room to reconnect."
        connect_button.disabled = false
    elif state == WebSocketPeer.STATE_CLOSED and connect_button.disabled:
        connection_status.text = "Unable to connect. Is the Node server running?"
        connect_button.disabled = false

    for player_id in players.keys():
        var p: Dictionary = players[player_id]
        var direction: Vector2 = p["input"]
        var position: Vector2 = p["position"] + direction * SPEED * delta
        var bounds := get_viewport_rect().size
        p["position"] = Vector2(clampf(position.x, 35.0, maxf(35.0, bounds.x - 35.0)), clampf(position.y, 205.0, maxf(205.0, bounds.y - 35.0)))
        players[player_id] = p
    queue_redraw()

func _send(value: Dictionary) -> void:
    if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
        peer.send_text(JSON.stringify(value))

func _on_message(message: Dictionary) -> void:
    match str(message.get("type", "")):
        "room_created":
            room_code = str(message.get("code", ""))
            room_label.text = "ROOM: " + room_code
            connection_status.text = "Room ready. Waiting for phones..."
        "player_joined":
            var id := str(message.get("playerId", ""))
            var n := int(message.get("number", 1))
            if not id.is_empty() and n >= 1 and n <= 4:
                players[id] = {"number": n, "position": STARTS[n - 1], "input": Vector2.ZERO, "action": false}
                connection_status.text = "%d phone(s) joined" % players.size()
        "input":
            var id := str(message.get("playerId", ""))
            if players.has(id):
                var p: Dictionary = players[id]
                p["input"] = Vector2(float(message.get("x", 0.0)), float(message.get("y", 0.0))).limit_length(1.0)
                p["action"] = message.get("action", false) == true
                players[id] = p
        "player_left":
            players.erase(str(message.get("playerId", "")))
            connection_status.text = "%d phone(s) joined" % players.size()
        "error":
            connection_status.text = "Server: " + str(message.get("message", "error"))

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(0, 185, size.x, maxf(0, size.y - 185)), Color("182c3b"))
    for player_id in players:
        var p: Dictionary = players[player_id]
        var n: int = p["number"]
        var point: Vector2 = p["position"]
        var color: Color = COLORS[n - 1]
        draw_circle(point, 27.0, color)
        draw_string(ThemeDB.fallback_font, point + Vector2(-17, 5), "P%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)
        if p["action"]:
            draw_arc(point, 34.0, 0.0, TAU, 40, Color.WHITE, 4.0)
    draw_string(ThemeDB.fallback_font, Vector2(22, size.y - 16), "Hold phone arrows to move. Hold ACTION for a white ring.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
