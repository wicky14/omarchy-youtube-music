import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "SearchModel.js" as SearchModel

Item {
  id: root

  property var shell: null
  property string moduleName: "omakid.youtube-music"

  property bool playerRunning: false
  property bool playerPaused: false
  property bool _suppressAutoNext: false
  property int playerVolume: 70
  property int reportedVolume: 70
  property int pendingVolume: -1
  property string playerTitle: ""
  property string playerArtist: ""
  property string playerAlbum: ""
  property string playerArtUrl: ""
  property real playerPosition: 0
  property real playerLength: 0
  property bool statusReady: false

  property var searchResults: []
  property bool searchRunning: false
  property string searchQuery: ""
  property string searchError: ""

  property var queue: []
  property int queueIndex: -1

  readonly property string runtimePath: Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-ytmusic"
  readonly property string statusPath: runtimePath + "/status.json"
  readonly property string playerSocket: runtimePath + "/mpv-socket"
  readonly property string playerPidPath: runtimePath + "/mpv.pid"
  readonly property string playerScript: Qt.resolvedUrl("ytmusic-player").toString().replace(/^file:\/\//, "")

  readonly property var mprisPlayer: {
    var players = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (p && p.identity && String(p.identity).toLowerCase().indexOf("mpv") >= 0) return p
    }
    return null
  }

  readonly property bool hasMedia: playerRunning || (mprisPlayer !== null)
  readonly property string title: {
    if (mprisPlayer && mprisPlayer.trackTitle) return mprisPlayer.trackTitle
    return playerTitle
  }
  readonly property string artist: {
    if (mprisPlayer && mprisPlayer.trackArtist) return mprisPlayer.trackArtist
    return playerArtist
  }
  readonly property bool isPlaying: {
    if (mprisPlayer) return mprisPlayer.isPlaying
    return playerRunning && !playerPaused
  }

  function ensureRuntimeDir() {
    mkdirProc.running = true
  }

  function search(query) {
    var q = String(query || "").trim()
    if (!q) return
    searchQuery = q
    searchRunning = true
    searchError = ""
    searchResults = []
    searchTimer.restart()
    searchProc.command = ["yt-dlp", "ytsearch10:" + q, "--flat-playlist", "--dump-json", "--no-warnings", "--no-playlist", "--ignore-errors"]
    searchProc.running = true
  }

  function playItem(item, fromIndex) {
    if (!item || !item.id && !item.url) return
    // Resolve the real index into searchResults by unique id, so we never
    // trust a possibly-stale fromIndex from a recycled Repeater delegate.
    var startIndex = -1
    if (fromIndex !== undefined && fromIndex >= 0 && fromIndex < searchResults.length
        && searchResults[fromIndex] && searchResults[fromIndex].id === item.id) {
      startIndex = fromIndex
    } else {
      for (var si = 0; si < searchResults.length; si++) {
        if (searchResults[si].id === item.id) { startIndex = si; break }
      }
    }
    var target = (startIndex >= 0) ? searchResults[startIndex] : item
    if (startIndex >= 0) {
      // Populate queue from the clicked result onward
      var newQueue = []
      for (var i = startIndex; i < searchResults.length; i++) {
        newQueue.push(searchResults[i])
      }
      if (queueIndex >= 0 && queueIndex < queue.length) {
        for (var j = queueIndex + 1; j < queue.length; j++) {
          var exists = false
          for (var k = 0; k < newQueue.length; k++) {
            if (newQueue[k].id === queue[j].id) { exists = true; break }
          }
          if (!exists) newQueue.push(queue[j])
        }
      }
      queue = newQueue
      queueIndex = 0
    } else {
      var idx = -1
      for (var i2 = 0; i2 < queue.length; i2++) {
        if (queue[i2].id === target.id) { idx = i2; break }
      }
      if (idx < 0) {
        queue = queue.concat([target])
        idx = queue.length - 1
      }
      queueIndex = idx
    }
    playUrl(target.url, target.title, target.channel)
  }

  function playUrl(url, title, artist) {
    playerTitle = title || ""
    playerArtist = artist || ""
    playerRunning = true
    playerPaused = false
    playerPosition = 0
    playerLength = 0
    writeStatus()

    _suppressAutoNext = playProc.running
    playProc.running = false
    var args = [
      root.playerScript,
      "start",
      url,
      (title || "YouTube Music"),
      (artist || ""),
      String(pendingVolume >= 0 ? pendingVolume : playerVolume)
    ]
    playProc.command = args
    playProc.running = true
  }

  function startMpv() {}

  function playPause() {
    if (mprisPlayer && mprisPlayer.canTogglePlaying) {
      mprisPlayer.togglePlaying()
      return
    }
    sendMpvCommand(["cycle", "pause"])
  }

  function seek(ratio) {
    if (playerLength <= 0) return
    var target = Math.max(0, Math.min(playerLength, ratio * playerLength))
    playerPosition = target
    sendMpvCommand(["seek", target, "absolute"])
  }

  function next() {
    if (mprisPlayer && mprisPlayer.canGoNext) {
      mprisPlayer.next()
      return
    }
    if (queueIndex < queue.length - 1) {
      var nextItem = queue[queueIndex + 1]
      queueIndex = queueIndex + 1
      playUrl(nextItem.url, nextItem.title, nextItem.channel)
    }
  }

  function previous() {
    if (mprisPlayer && mprisPlayer.canGoPrevious) {
      mprisPlayer.previous()
      return
    }
    if (queueIndex > 0) {
      var prevItem = queue[queueIndex - 1]
      queueIndex = queueIndex - 1
      playUrl(prevItem.url, prevItem.title, prevItem.channel)
    }
  }

  function stop() {
    if (mprisPlayer && mprisPlayer.canPause) mprisPlayer.pause()
    sendMpvCommand(["stop"])
    _suppressAutoNext = true
    stopProc.command = [root.playerScript, "stop"]
    stopProc.running = true
    playerRunning = false
    playerPaused = false
    playerTitle = ""
    playerArtist = ""
    playerAlbum = ""
    playerArtUrl = ""
    writeStatus()
  }

  function setVolume(value) {
    var v = Math.max(0, Math.min(100, Math.round(value)))
    pendingVolume = v
    playerVolume = v
    sendMpvCommand(["set_property", "volume", v])
    writeStatus()
  }

  function changeVolume(delta) {
    var current = pendingVolume >= 0 ? pendingVolume : playerVolume
    setVolume(current + (delta > 0 ? 5 : -5))
  }

  function removeFromQueue(index) {
    if (index < 0 || index >= queue.length) return
    var newQueue = []
    for (var i = 0; i < queue.length; i++) {
      if (i !== index) newQueue.push(queue[i])
    }
    queue = newQueue
    if (index < queueIndex) queueIndex = queueIndex - 1
    else if (index === queueIndex) {
      if (queue.length === 0) { queueIndex = -1; stop() }
      else if (queueIndex >= queue.length) { queueIndex = queue.length - 1 }
    }
  }

  function clearQueue() {
    queue = []
    queueIndex = -1
    stop()
  }

  function sendMpvCommand(args) {
    mpvSocket.pendingCommand = JSON.stringify({ "command": args }) + "\n"
    mpvSocket.path = playerSocket
    if (mpvSocket.connected) {
      mpvSocket.write(mpvSocket.pendingCommand)
      mpvSocket.pendingCommand = ""
    } else {
      mpvSocket.connected = true
    }
  }

  function handleMpvResponse(line) {
    if (!line || line[0] !== "{") return
    var obj
    try { obj = JSON.parse(line) } catch (e) { return }
    if (obj.error && obj.error !== "success") return
    if (obj.request_id === 1 && typeof obj.data === "number") {
      playerPosition = obj.data
    } else if (obj.request_id === 2 && typeof obj.data === "number") {
      playerLength = obj.data
    }
  }

  function queryPosition() {
    mpvSocket.pendingCommand = JSON.stringify({ "command": ["get_property", "time-pos"], "request_id": 1 }) + "\n"
    mpvSocket.pendingCommand += JSON.stringify({ "command": ["get_property", "duration"], "request_id": 2 }) + "\n"
    mpvSocket.path = playerSocket
    if (mpvSocket.connected) {
      mpvSocket.write(mpvSocket.pendingCommand)
      mpvSocket.pendingCommand = ""
    } else {
      mpvSocket.connected = true
    }
  }

  function writeStatus() {
    ensureRuntimeDir()
    var status = {
      running: playerRunning,
      paused: playerPaused,
      volume: pendingVolume >= 0 ? pendingVolume : playerVolume,
      title: playerTitle,
      artist: playerArtist,
      album: playerAlbum,
      artUrl: playerArtUrl,
      position: playerPosition,
      length: playerLength,
      queueIndex: queueIndex,
      queueLength: queue.length,
      queue: queue
    }
    statusFile.setText(JSON.stringify(status) + "\n")
  }

  function handleRestore(data) {
    var s
    try { s = JSON.parse(data || "{}") } catch (e) { s = {} }
    if (s.volume !== undefined && isFinite(Number(s.volume))) {
      var v = Math.round(Number(s.volume))
      v = Math.max(0, Math.min(100, v))
      root.reportedVolume = v
      if (root.pendingVolume < 0) root.playerVolume = v
    }
    if (Array.isArray(s.queue)) {
      root.queue = s.queue
      if (typeof s.queueIndex === "number" && s.queueIndex >= 0 && s.queueIndex < root.queue.length) {
        root.queueIndex = Math.floor(s.queueIndex)
      }
      if (s.title) root.playerTitle = s.title
      if (s.artist) root.playerArtist = s.artist
      if (s.album) root.playerAlbum = s.album
      if (s.artUrl) root.playerArtUrl = s.artUrl
      if (s.length && isFinite(Number(s.length))) root.playerLength = Number(s.length)
      root.playerRunning = !!s.running
      root.playerPaused = !!s.paused
      if (s.running) root.queryPosition()
    }
  }

  function applyMprisState() {
    if (!mprisPlayer) return
    if (mprisPlayer.trackTitle) playerTitle = mprisPlayer.trackTitle
    if (mprisPlayer.trackArtist) playerArtist = mprisPlayer.trackArtist
    if (mprisPlayer.trackAlbum) playerAlbum = mprisPlayer.trackAlbum
    if (mprisPlayer.trackArtUrl) playerArtUrl = mprisPlayer.trackArtUrl
    playerRunning = true
    playerPaused = !mprisPlayer.isPlaying
    playerPosition = mprisPlayer.position || 0
    playerLength = mprisPlayer.length || 0
  }

  onMprisPlayerChanged: {
    if (mprisPlayer) applyMprisState()
  }

  Connections {
    target: root.mprisPlayer
    function onTrackTitleChanged() { root.applyMprisState() }
    function onTrackArtistChanged() { root.applyMprisState() }
    function onIsPlayingChanged() { root.applyMprisState() }
    function onPositionChanged() { root.playerPosition = root.mprisPlayer ? root.mprisPlayer.position : 0 }
    function onLengthChanged() { root.playerLength = root.mprisPlayer ? root.mprisPlayer.length : 0 }
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.runtimePath]
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var results = SearchModel.parseSearchResults(text)
        root.searchResults = results
        root.searchRunning = false
        searchTimer.stop()
        if (results.length === 0) root.searchError = "No results found for \"" + root.searchQuery + "\""
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && text.length > 0 && root.searchResults.length === 0) {
          var msg = String(text).trim()
          if (msg.indexOf("ERROR") >= 0) root.searchError = msg.slice(0, 120)
        }
      }
    }
    onExited: function(code) {
      searchTimer.stop()
      root.searchRunning = false
      if (code !== 0 && root.searchResults.length === 0) {
        root.searchError = root.searchError || "Search failed — try a different query"
      }
    }
  }

  Process {
    id: playProc
    stdout: StdioCollector { waitForEnd: false }
    stderr: StdioCollector {
      waitForEnd: false
    }
    onExited: function(code) {
      if (!root._suppressAutoNext) {
        // Genuine track end: clear "now playing" and advance the queue.
        root.playerRunning = false
        root.playerPaused = false
        root.playerTitle = ""
        root.playerArtist = ""
        root.writeStatus()
        if (root.queueIndex >= 0 && root.queueIndex < root.queue.length - 1) {
          root.next()
        }
      } else {
        // Intentional stop or restart: nothing to advance; just re-arm.
        root._suppressAutoNext = false
      }
    }
  }

  Process {
    id: stopProc
    onExited: function(code) {}
  }

  Socket {
    id: mpvSocket
    property string pendingCommand: ""
    connected: false
    path: root.playerSocket

    parser: SplitParser {
      onRead: function(data) {
        root.handleMpvResponse(String(data).trim())
      }
    }

    onConnectedChanged: {
      if (connected && pendingCommand !== "") {
        write(pendingCommand)
        pendingCommand = ""
      }
    }
  }

  Timer {
    id: searchTimer
    interval: 8000
    running: root.searchRunning
    repeat: false
    onTriggered: {
      if (root.searchRunning) {
        searchProc.running = false
        root.searchRunning = false
        if (root.searchResults.length === 0) root.searchError = "Search timed out — try again"
      }
    }
  }

  Timer {
    interval: 3000
    running: root.playerRunning
    repeat: true
    onTriggered: root.writeStatus()
  }

  Timer {
    interval: 1000
    running: root.playerRunning && !root.playerPaused
    repeat: true
    onTriggered: root.queryPosition()
  }

  FileView {
    id: statusFile
    path: root.statusReady ? root.statusPath : ""
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      try {
        var s = JSON.parse(text() || "{}")
        if (s.volume !== undefined) {
          var v = Math.round(Number(s.volume))
          if (isFinite(v)) {
            root.reportedVolume = Math.max(0, Math.min(100, v))
            if (root.pendingVolume < 0) root.playerVolume = root.reportedVolume
          }
        }
      } catch (e) {}
    }
    onFileChanged: reload()
  }

  IpcHandler {
    target: "youtube-music"

    function search(query: string): string {
      root.search(query)
      return "ok"
    }

    function playPause(): string {
      root.playPause()
      return "ok"
    }

    function next(): string {
      root.next()
      return "ok"
    }

    function previous(): string {
      root.previous()
      return "ok"
    }

    function stop(): string {
      root.stop()
      return "ok"
    }

    function volume(value: string): string {
      root.setVolume(parseInt(value) || 70)
      return "ok"
    }

    function status(): string {
      return JSON.stringify({
        running: root.playerRunning,
        paused: root.playerPaused,
        volume: root.pendingVolume >= 0 ? root.pendingVolume : root.playerVolume,
        title: root.title,
        artist: root.artist,
        hasMedia: root.hasMedia,
        isPlaying: root.isPlaying,
        queueIndex: root.queueIndex,
        queueLength: root.queue.length
      })
    }

    function ping(): string {
      return "ok"
    }
  }

  Component.onCompleted: {
    ensureRuntimeDir()
    statusInitProc.running = true
  }

  Process {
    id: statusInitProc
    command: ["mkdir", "-p", root.runtimePath]
    onExited: function(code) {
      root.statusReady = true
      // After a restart there is no playProc running. Detect whether a
      // detached mpv survived; if so, reconnect to it and restore state.
      if (!root.playProc.running) {
        checkPlayerProc.running = true
      }
    }
  }

  // Detect whether a detached mpv is still alive after a restart.
  Process {
    id: checkPlayerProc
    command: [root.playerScript, "is-running"]
    stdout: StdioCollector { waitForEnd: false }
    onExited: function(code) {
      if (code === 0) {
        // mpv survived: restore playback state and treat it as current player.
        root.playerRunning = true
        readStatusProc.running = true
      } else {
        root.playerRunning = false
        root.playerPaused = false
        root.playerTitle = ""
        root.playerArtist = ""
        root.queue = []
        root.queueIndex = -1
      }
    }
  }

  // Restore full queue/track/volume state from the persisted status.json.
  Process {
    id: readStatusProc
    command: ["cat", root.statusPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.handleRestore(text)
      }
    }
  }
}
