extends Node
## Autoload: transport only. All positions, roles and interactions are handled by Main.
signal message_received(message: Dictionary)
signal disconnected()
## How long to keep trying to get back into our room after the connection drops.
## Matches the server's 30s host grace period.
const RETRY_WINDOW_SEC := 30.0
const RETRY_EVERY_SEC := 2.0
var socket := WebSocketPeer.new()
var active := false
var connecting := false
var server_url := ""
var room_code := ""
var host_token := ""
var retrying := false
var retry_deadline := 0.0
var next_retry := 0.0

func connect_to_server(url: String) -> int:
    server_url = url
    room_code = ""
    host_token = ""
    retrying = false
    return _open()

func _open() -> int:
    socket = WebSocketPeer.new()
    active = false
    var err := socket.connect_to_url(server_url)
    connecting = err == OK
    return err

func send_message(data: Dictionary) -> void:
    if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        socket.send_text(JSON.stringify(data))

func _now() -> float:
    return Time.get_ticks_msec() / 1000.0

func _give_up() -> void:
    retrying = false
    room_code = ""
    host_token = ""
    disconnected.emit()

func _process(_delta: float) -> void:
    socket.poll()
    var state: int = socket.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        if not active:
            active = true
            connecting = false
            if retrying:
                # Back online: ask for our old room instead of making a new one.
                send_message({"type": "rejoin_room", "code": room_code, "hostToken": host_token})
            else:
                send_message({"type": "create_room"})
        while socket.get_available_packet_count() > 0:
            var decoded: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
            if typeof(decoded) == TYPE_DICTIONARY:
                message_received.emit(decoded)
                _track_room(decoded)
    elif state == WebSocketPeer.STATE_CLOSED:
        if active or connecting:
            active = false
            connecting = false
            if host_token.is_empty():
                disconnected.emit()
                return
            if not retrying:
                retrying = true
                retry_deadline = _now() + RETRY_WINDOW_SEC
            next_retry = _now() + RETRY_EVERY_SEC
        elif retrying and _now() >= next_retry:
            if _now() >= retry_deadline:
                _give_up()
            elif _open() != OK:
                next_retry = _now() + RETRY_EVERY_SEC

func _track_room(msg: Dictionary) -> void:
    match str(msg.get("type", "")):
        "room_created":
            room_code = str(msg.get("code", ""))
            host_token = str(msg.get("hostToken", ""))
        "room_rejoined":
            retrying = false
        "error":
            # The room is gone (grace period ran out) or the token was refused.
            if retrying:
                socket.close()
                connecting = false
                active = false
                _give_up()
