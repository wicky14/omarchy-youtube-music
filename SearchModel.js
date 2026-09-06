.pragma library

function parseSearchResults(jsonText) {
  try {
    var lines = String(jsonText || "").split("\n")
    var results = []
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line[0] !== "{") continue
      try {
        var item = JSON.parse(line)
        if (!item || !item.id) continue
        results.push({
          id: item.id || "",
          title: item.title || item.fulltitle || "Unknown",
          channel: item.channel || item.uploader || item.creator || "Unknown",
          duration: item.duration || 0,
          thumbnail: item.thumbnail || item.thumbnails ? (Array.isArray(item.thumbnails) && item.thumbnails.length > 0 ? item.thumbnails[item.thumbnails.length - 1].url : "") : "",
          url: item.url || ("https://www.youtube.com/watch?v=" + item.id),
          viewCount: item.view_count || 0
        })
      } catch (e) {}
    }
    return results
  } catch (e) {
    return []
  }
}

function formatDuration(seconds) {
  if (!seconds || seconds <= 0) return "0:00"
  var h = Math.floor(seconds / 3600)
  var m = Math.floor((seconds % 3600) / 60)
  var s = Math.floor(seconds % 60)
  if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
  return m + ":" + (s < 10 ? "0" : "") + s
}

function formatNumber(n) {
  if (!n) return "0"
  if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
  if (n >= 1000) return (n / 1000).toFixed(1) + "K"
  return String(n)
}

function formatTime(seconds) {
  return formatDuration(seconds)
}

function truncate(text, limit) {
  var s = String(text || "")
  return s.length > limit ? s.slice(0, limit) + "..." : s
}
