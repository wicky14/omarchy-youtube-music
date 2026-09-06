import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons
import "SearchModel.js" as SearchModel

BarWidget {
  id: root
  moduleName: "omakid.youtube-music"

  readonly property var ytmService: bar?.shell?.firstPartyServiceFor("omakid.youtube-music")

  property bool popupOpen: false

  function close() { popupOpen = false }

  implicitWidth: button.implicitWidth
  implicitHeight: barSize

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf001"
    tooltipText: "YouTube Music"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) {
        if (root.ytmService) root.ytmService.stop()
        return
      }
      if (mouseButton === Qt.RightButton) {
        if (root.ytmService) root.ytmService.playPause()
        return
      }
      root.popupOpen = !root.popupOpen
    }
    onWheelMoved: function(delta) {
      if (root.ytmService) root.ytmService.changeVolume(delta)
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    focusTarget: searchField
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(Style.space(560))

    Column {
      id: panelContent
      anchors.fill: parent
      spacing: 0

      Item {
        width: parent.width
        height: Style.space(36)

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "YOUTUBE MUSIC"
          color: Qt.darker(root.bar.foreground, 1.2)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      Item {
        width: parent.width
        height: searchField.implicitHeight + Style.space(12)

        TextField {
          id: searchField
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "Search songs, artists..."
          maximumLength: 200
          onTextChanged: searchDebounce.restart()
          onAccepted: {
            searchDebounce.stop()
            doSearch()
          }
        }

        Timer {
          id: searchDebounce
          interval: 400
          repeat: false
          onTriggered: doSearch()
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      Item {
        width: parent.width
        height: (root.ytmService && root.ytmService.hasMedia) ? nowPlayingCol.implicitHeight + Style.space(12) : 0
        visible: root.ytmService && root.ytmService.hasMedia

        Column {
          id: nowPlayingCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Row {
            spacing: Style.space(10)
            width: parent.width

            BorderSurface {
              width: Style.space(56)
              height: Style.space(56)
              radius: Style.spacing.labelGap
              color: Style.normalFillFor(root.bar.foreground, Color.accent)
              borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

              Image {
                anchors.fill: parent
                anchors.margins: Style.space(2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                source: root.ytmService ? (root.ytmService.playerArtUrl || "") : ""
                visible: source !== ""
              }

              Text {
                anchors.centerIn: parent
                visible: !root.ytmService || !root.ytmService.playerArtUrl
                text: "\uf001"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.displayLarge
              }
            }

            Column {
              spacing: Style.space(2)
              width: parent.width - Style.space(66)

              Text {
                textFormat: Text.PlainText
                text: (root.ytmService ? root.ytmService.title : "") || "Nothing playing"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: root.ytmService ? root.ytmService.artist : ""
                color: Qt.darker(root.bar.foreground, 1.3)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                width: parent.width
                visible: text !== ""
              }
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(8)

            Button {
              iconText: "\uf048"
              foreground: root.bar.foreground
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              enabled: root.ytmService && root.ytmService.queueIndex > 0
              opacity: enabled ? 1.0 : 0.4
              onClicked: if (root.ytmService) root.ytmService.previous()
            }

            Button {
              iconText: (root.ytmService && root.ytmService.isPlaying) ? "\uf04c" : "\uf04b"
              foreground: root.bar.foreground
              horizontalPadding: Style.spacing.panelGap
              verticalPadding: Style.spacing.controlPaddingY
              iconSize: Style.font.iconLarge
              enabled: root.ytmService && root.ytmService.hasMedia
              opacity: enabled ? 1.0 : 0.4
              onClicked: if (root.ytmService) root.ytmService.playPause()
            }

            Button {
              iconText: "\uf051"
              foreground: root.bar.foreground
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              enabled: root.ytmService && root.ytmService.queue && root.ytmService.queueIndex < root.ytmService.queue.length - 1
              opacity: enabled ? 1.0 : 0.4
              onClicked: if (root.ytmService) root.ytmService.next()
            }
          }

          PanelSlider {
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            bar: root.bar
            minimum: 0
            maximum: 1
            step: 0.01
            enabled: root.ytmService && root.ytmService.hasMedia && root.ytmService.playerLength > 0
            opacity: enabled ? 1.0 : 0.0

            value: (root.ytmService && root.ytmService.playerLength > 0)
              ? Math.min(1, Math.max(0, root.ytmService.playerPosition / root.ytmService.playerLength))
              : 0

            onReleased: {
              if (root.ytmService) root.ytmService.seek(value)
            }
          }
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      // Scrollable content area
      Item {
        width: parent.width
        height: parent.height
          - Style.space(36)                      // header
          - Style.space(1)                       // separator
          - (searchField.implicitHeight + Style.space(12))  // search row
          - Style.space(1)                       // separator
          - (root.ytmService && root.ytmService.hasMedia ? nowPlayingCol.implicitHeight + Style.space(12) : 0) // now playing
          - Style.space(1)                       // separator

        Flickable {
          id: panelScroll
          anchors.fill: parent
          clip: true
          contentHeight: scrollContent.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar {
            policy: panelScroll.contentHeight > panelScroll.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
          }

          Column {
            id: scrollContent
            width: parent.width
            spacing: 0

          Item {
            width: parent.width
            height: searchField.text.length > 0 ? searchCol.implicitHeight : 0
            visible: searchField.text.length > 0

            Column {
              id: searchCol
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: 0

              PanelSeparator { foreground: root.bar.foreground }

              Text {
                width: parent.width
                height: root.ytmService && root.ytmService.searchRunning ? Style.space(36) : 0
                visible: root.ytmService && root.ytmService.searchRunning
                text: "Searching..."
                textFormat: Text.PlainText
                color: Qt.darker(root.bar.foreground, 1.3)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }

              Text {
                width: parent.width
                height: root.ytmService && root.ytmService.searchError ? Style.space(32) : 0
                visible: root.ytmService && root.ytmService.searchError
                text: root.ytmService ? root.ytmService.searchError : ""
                textFormat: Text.PlainText
                color: Color.urgent
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }

              Repeater {
                model: root.ytmService ? root.ytmService.searchResults : []

                BorderSurface {
                  id: resultRow
                  required property var modelData
                  required property int index
                  width: searchCol.width
                  height: Style.space(48)
                  radius: 0
                  color: rowMouse.containsMouse
                    ? Style.hoverFillFor(root.bar.foreground, Color.accent)
                    : "transparent"
                  borderSpec: Border.none()

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(8)

                    BorderSurface {
                      width: Style.space(36)
                      height: Style.space(36)
                      radius: Style.spacing.labelGap
                      color: "transparent"
                      borderSpec: Border.none()
                      anchors.verticalCenter: parent.verticalCenter

                      Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        source: resultRow.modelData.thumbnail || ""
                        visible: source !== ""
                      }

                      Text {
                        anchors.centerIn: parent
                        visible: !resultRow.modelData.thumbnail
                        textFormat: Text.PlainText
                        text: resultRow.index + 1
                        color: Qt.darker(root.bar.foreground, 1.5)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    Column {
                      width: parent.width - Style.space(44) - Style.space(56)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText
                        text: resultRow.modelData.title || "Unknown"
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: (resultRow.modelData.channel || "Unknown")
                          + (resultRow.modelData.duration ? "  \u00b7  " + SearchModel.formatDuration(resultRow.modelData.duration) : "")
                        color: Qt.darker(root.bar.foreground, 1.5)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: SearchModel.formatNumber(resultRow.modelData.viewCount)
                      color: Qt.darker(root.bar.foreground, 1.8)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.caption
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(48)
                      horizontalAlignment: Text.AlignRight
                    }
                  }

                  MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.ytmService) {
                        root.ytmService.playItem(resultRow.modelData, resultRow.index)
                        searchField.text = ""
                      }
                    }
                  }
                }
              }

              Text {
                width: parent.width
                height: Style.space(44)
                visible: !root.ytmService || (!root.ytmService.searchRunning && root.ytmService.searchResults.length === 0 && !root.ytmService.searchError)
                text: "Type to search..."
                textFormat: Text.PlainText
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          Item {
            width: parent.width
            height: searchField.text.length === 0 && root.ytmService && root.ytmService.queue && root.ytmService.queue.length > 0 ? queueCol.implicitHeight : 0
            visible: searchField.text.length === 0 && root.ytmService && root.ytmService.queue && root.ytmService.queue.length > 0

            Column {
              id: queueCol
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: 0

              PanelSeparator { foreground: root.bar.foreground }

              Item {
                width: parent.width
                height: Style.space(32)

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "QUEUE (" + (root.ytmService ? root.ytmService.queue.length : 0) + ")"
                  color: Qt.darker(root.bar.foreground, 1.3)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Button {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Clear"
                  fontSize: Style.font.caption
                  foreground: Color.urgent
                  horizontalPadding: Style.space(6)
                  verticalPadding: Style.space(2)
                  onClicked: if (root.ytmService) root.ytmService.clearQueue()
                }
              }

              Repeater {
                model: root.ytmService ? root.ytmService.queue : []

                BorderSurface {
                  id: queueRow
                  required property var modelData
                  required property int index
                  width: queueCol.width
                  height: Style.space(44)
                  radius: 0
                  color: root.ytmService && root.ytmService.queueIndex === queueRow.index
                    ? Style.selectedFillFor(root.bar.foreground, Color.accent)
                    : (qMouse.containsMouse
                      ? Style.hoverFillFor(root.bar.foreground, Color.accent)
                      : "transparent")
                  borderSpec: Border.none()

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(8)

                    Text {
                      textFormat: Text.PlainText
                      text: root.ytmService && root.ytmService.queueIndex === queueRow.index ? "\uf04b" : (queueRow.index + 1)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: root.ytmService && root.ytmService.queueIndex === queueRow.index ? Style.font.body : Style.font.caption
                      width: Style.space(20)
                      horizontalAlignment: Text.AlignHCenter
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                      width: parent.width - Style.space(28) - Style.space(24)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText
                        text: queueRow.modelData.title || "Unknown"
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: root.ytmService && root.ytmService.queueIndex === queueRow.index
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: queueRow.modelData.channel || "Unknown"
                        color: Qt.darker(root.bar.foreground, 1.5)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        width: parent.width
                      }
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: "\uf00d"
                      color: qRemoveMouse.containsMouse ? Color.urgent : Qt.darker(root.bar.foreground, 1.5)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.body
                      anchors.verticalCenter: parent.verticalCenter
                      width: Style.space(20)
                      horizontalAlignment: Text.AlignHCenter

                      MouseArea {
                        id: qRemoveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.ytmService) root.ytmService.removeFromQueue(queueRow.index)
                      }
                    }
                  }

                  MouseArea {
                    id: qMouse
                    anchors.fill: parent
                    anchors.rightMargin: Style.space(24)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.ytmService && root.ytmService.queueIndex !== queueRow.index) {
                        root.ytmService.queueIndex = queueRow.index
                        var item = root.ytmService.queue[queueRow.index]
                        if (item) root.ytmService.playUrl(item.url, item.title, item.channel)
                      }
                    }
                  }
                }
              }
            }
          }

          Item {
            width: parent.width
            height: (!root.ytmService || !root.ytmService.hasMedia) && searchField.text.length === 0 && (!root.ytmService || !root.ytmService.queue || root.ytmService.queue.length === 0) ? Style.space(60) : 0
            visible: (!root.ytmService || !root.ytmService.hasMedia) && searchField.text.length === 0 && (!root.ytmService || !root.ytmService.queue || root.ytmService.queue.length === 0)

            Column {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                textFormat: Text.PlainText
                text: "\uf001"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.displayLarge
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: "Search to start playing"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }
          }
        }
      }
    }
  }
  }

  function doSearch() {

    var q = searchField.text.trim()
    if (q.length < 2) return
    if (root.ytmService) root.ytmService.search(q)
  }
}