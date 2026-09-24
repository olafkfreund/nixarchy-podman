import QtQuick
import qs.Ui
import qs.Commons
import "Model.js" as Model

// The `?` sheet. Omarchy is a keyboard-first shell, so the panel says out
// loud what it listens for rather than leaving it to the tooltips. The list
// itself lives in Model.SHORTCUTS, which the README quotes too.
Item {
  id: root

  // The key column was a fixed Style.space(90), sized for the popup's base
  // rung: every row paid the width of the longest one, and at the menu's rung
  // the widest string ("tab  shift+tab") did not fit (#17). Measured instead,
  // from the keys themselves at whatever rung they are drawn, so the column is
  // exactly as wide as it needs to be and the text gets the rest.
  //
  // Measured by laying the keys out invisibly rather than by driving a
  // TextMetrics from inside a binding: that would write the property it then
  // reads back, and re-evaluate on its own output.
  Item {
    id: keyMeasure
    visible: false
    Repeater {
      model: Model.SHORTCUTS
      Text {
        required property var modelData
        text: modelData.keys
        textFormat: Text.PlainText
        font.family: root.fontFamily
        font.pixelSize: root.fontRow
      }
    }
  }

  readonly property int keyColumnWidth: Math.ceil(keyMeasure.childrenRect.width)

  // What the sheet needs to show every row, so the host can make room (#17).
  // Matches the Flickable's margins below; change them together.
  readonly property int wantedHeight: sheetColumn.implicitHeight + Style.spacing.md * 2

  property bool opened: false
  property color foreground: Color.foreground
  property color background: Color.popups.background
  property string fontFamily: Style.font.family
  // Sized by the host's rung, not a factor (#30).
  property int fontRow: Style.font.caption
  property int fontIcon: Style.font.icon

  readonly property color dim: Qt.darker(foreground, 1.5)

  signal dismissed()

  visible: opened

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(root.background.r, root.background.g, root.background.b, 1)

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismissed()
    }

    // Bounded by the card, so overflow has somewhere to go. `interactive` only
    // once it actually overflows: a sheet that fits must not acquire a scroll
    // gesture, and a reference that silently has more below is worse than one
    // that fits -- which is why the width is fixed first (#17).
    Flickable {
      anchors.fill: parent
      anchors.margins: Style.spacing.md
      contentWidth: width
      contentHeight: sheetColumn.implicitHeight
      interactive: contentHeight > height
      flickableDirection: Flickable.VerticalFlick
      boundsBehavior: Flickable.StopAtBounds
      clip: true

      Column {
        id: sheetColumn
        width: parent.width
        // Centred while it fits, top-aligned once it does not: overflow has to
        // go downward where scrolling reaches it. Lines lost off the top give
        // the reader no sign that anything is missing.
        y: Math.max(0, (parent.height - implicitHeight) / 2)
        spacing: Style.spacing.lg

        Row {
          width: parent.width
          spacing: Style.spacing.md

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Model.Glyph.keyboard
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.fontIcon
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "KEYBOARD"
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: root.fontRow
            font.bold: true
            font.letterSpacing: 1.2
          }
        }

        Repeater {
          model: Model.shortcutGroups()

          delegate: Column {
            required property var modelData

            width: parent.width
            spacing: Style.spacing.xs
            topPadding: Style.spacing.xs

            PanelSectionHeader {
              text: modelData.title.toUpperCase()
              textFormat: Text.PlainText
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: modelData.entries

              delegate: Item {
                required property var modelData

                width: parent.width
                implicitHeight: entryText.implicitHeight + Style.spacing.xs
                height: implicitHeight

                Text {
                  id: entryKeys
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: root.keyColumnWidth
                  text: modelData.keys
                  textFormat: Text.PlainText
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: root.fontRow
                }

                Text {
                  id: entryText
                  anchors.left: entryKeys.right
                  anchors.leftMargin: Style.spacing.md
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.text
                  textFormat: Text.PlainText
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: root.fontRow
                  // Wrap, never elide: a row that loses its end is a reference
                  // entry the reader cannot use (#17).
                  wrapMode: Text.WordWrap
                  elide: Text.ElideNone
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          topPadding: Style.spacing.md
          horizontalAlignment: Text.AlignHCenter
          text: "press ? or esc to go back"
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: root.fontRow
        }
      }
    }
  }
}
