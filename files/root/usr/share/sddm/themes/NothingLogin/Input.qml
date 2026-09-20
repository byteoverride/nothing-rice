import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

TextField {
    id: field
    placeholderTextColor: "#8a8a8a"
    palette.text: config.color
    font.pointSize: config.fontSize
    font.family: config.font
    width: parent.width
    background: Rectangle {
        // Nothing-style dark pill with a red focus ring
        color: field.focus ? "#1a1a1a" : "#121212"
        radius: 100
        opacity: 0.82
        border.width: field.focus ? 2 : 1
        border.color: field.focus ? "#d71921" : "#2e2e2e"
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on color        { ColorAnimation { duration: 120 } }
    }
}
