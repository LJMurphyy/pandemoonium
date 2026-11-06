extends Node
## Autoload: transport only. All positions, roles and interactions are handled by Main.
signal message_received(message: Dictionary)
signal disconnected()
var socket := WebSocketPeer.new()
var active := false
var connecting := false

func connect_to_server(url: String) -> int:
    socket = WebSocketPeer.new()
    active = false
    connecting = true
    return socket.connect_to_url(url)

func send_message(data: Dictionary) -> void:
    if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        socket.send_text(JSON.stringify(data))

func _process(_delta: float) -> void:
    socket.poll()
    var state: int = socket.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        if not active:
            active = true
            connecting = false
            send_message({"type": "create_room"})
        while socket.get_available_packet_count() > 0:
            var decoded: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
            if typeof(decoded) == TYPE_DICTIONARY:
                message_received.emit(decoded)
    elif state == WebSocketPeer.STATE_CLOSED and (active or connecting):
        active = false
        connecting = false
        disconnected.emit()
