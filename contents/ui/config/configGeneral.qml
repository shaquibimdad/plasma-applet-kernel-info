import QtGraphicalEffects 1.12 as QtGraphicalEffects
import QtQuick 2.4
import QtQuick.Controls 2.5 as QQC2
import QtQuick.Dialogs 1.2
import QtQuick.Layouts 1.0 as QtLayouts
import org.kde.kirigami 2.4 as Kirigami

Kirigami.FormLayout {
    id: page

    property string cfg_fontFamily
    property alias cfg_boldText: boldCheckBox.checked
    property alias cfg_italicText: italicCheckBox.checked
    property alias cfg_fontColor: fontColor.text
    property alias cfg_fontSize: fontSize.value

    ListModel {
        id: fontsModel

        Component.onCompleted: {
            var arr = []; // use temp array to avoid constant binding stuff
            arr.push({
                "text": i18nc("Use default font", "Default"),
                "value": ""
            });
            var fonts = Qt.fontFamilies();
            var foundIndex = 0;
            for (var i = 0, j = fonts.length; i < j; ++i) {
                arr.push({
                    "text": fonts[i],
                    "value": fonts[i]
                });
            }
            append(arr);
        }
    }

    QtLayouts.RowLayout {
        QtLayouts.Layout.fillWidth: true
        Kirigami.FormData.label: i18n("Font style:")

        QQC2.ComboBox {
            id: fontFamilyComboBox

            QtLayouts.Layout.fillWidth: true
            currentIndex: 0
            // ComboBox's sizing is just utterly broken
            QtLayouts.Layout.minimumWidth: units.gridUnit * 10
            model: fontsModel
            // doesn't autodeduce from model because we manually populate it
            textRole: "text"
            onCurrentIndexChanged: {
                var current = model.get(currentIndex);
                if (current) {
                    cfg_fontFamily = current.value;
                    appearancePage.configurationChanged();
                }
            }
        }

        QQC2.Button {
            id: boldCheckBox

            icon.name: "format-text-bold"
            checkable: true
            Accessible.name: tooltip

            QQC2.ToolTip {
                text: i18n("Bold text")
            }

        }

        QQC2.Button {
            id: italicCheckBox

            icon.name: "format-text-italic"
            checkable: true
            Accessible.name: tooltip

            QQC2.ToolTip {
                text: i18n("Italic text")
            }

        }

    }

    QtLayouts.RowLayout {
        QtLayouts.Layout.fillWidth: true
        Kirigami.FormData.label: i18n("Font Size:")
        Kirigami.FormData.buddyFor: fontSize

        QQC2.SpinBox {
            id: fontSize

            enabled: cfg_fixedFont
            from: 1
            to: 60
            editable: true

            validator: IntValidator {
                locale: control.locale.name
                bottom: Math.min(control.from, control.to)
                top: Math.max(control.from, control.to)
            }

        }

    }

    QQC2.TextField {
        id: fontColor

        readonly property string defaultText: plasmoid.configuration.fontColor
        property bool showAlphaChannel: true
        property bool showPreviewBg: true
        property string configKey: ''
        property string defaultColor: ''
        property string value: {
            if (configKey)
                return plasmoid.configuration[configKey];
            else
                return "#000";
        }
        readonly property color defaultColorValue: defaultColor
        readonly property color valueColor: {
            if (value == '' && defaultColor)
                return defaultColor;
            else
                return value;
        }
        readonly property int defaultWidth: Math.ceil(fontMetrics.advanceWidth(defaultText))

        // Note: There's a function in Kirigami 5.12:
        // Kirigami.ColorUtils.linearInterpolation(aColor, bColor, balance)
        // but it requires KF5 5.69, while Ubuntu 20.04 currently only has KF5 5.68
        // https://invent.kde.org/frameworks/kirigami/-/blob/master/src/colorutils.h#L88
        // https://invent.kde.org/frameworks/kirigami/-/blob/master/src/colorutils.cpp#L59
        // https://repology.org/project/plasma-framework/versions
        function isTransparent(c) {
            return c.r == 0 && c.g == 0 && c.b == 0 && c.a == 0;
        }

        function scaleAlpha(c, factor) {
            return Qt.rgba(c.r, c.g, c.b, c.a * factor);
        }

        function lerpDouble(a, b, balance) {
            return a + (b - a) * balance;
        }

        function lerpColor(oneColor, twoColor, balance) {
            if (isTransparent(oneColor))
                return scaleAlpha(twoColor, balance);

            if (isTransparent(twoColor))
                return scaleAlpha(oneColor, balance);

            var r = lerpDouble(oneColor.r, twoColor.r, balance);
            var g = lerpDouble(oneColor.g, twoColor.g, balance);
            var b = lerpDouble(oneColor.b, twoColor.b, balance);
            var a = lerpDouble(oneColor.a, twoColor.a, balance);
            return Qt.rgba(r, g, b, a);
        }

        Kirigami.FormData.label: i18n("Font Color:")
        font.family: "monospace"
        placeholderText: defaultColor ? defaultColor : defaultText
        onTextChanged: {
            // Make sure the text is:
            //   Empty (use default)
            //   or #123 or #112233 or #11223344 before applying the color.
            if (text.length === 0 || (text.indexOf('#') === 0 && (text.length == 4 || text.length == 7 || text.length == 9)))
                fontColor.value = text;

        }
        onValueChanged: {
            if (!activeFocus)
                text = fontColor.value;

            if (configKey) {
                if (value == defaultColorValue)
                    plasmoid.configuration[configKey] = "";
                else
                    plasmoid.configuration[configKey] = value;
            }
        }
        leftPadding: rightPadding + mouseArea.height + rightPadding
        implicitWidth: rightPadding + Math.max(defaultWidth, contentWidth) + leftPadding

        FontMetrics {
            id: fontMetrics

            font.family: fontColor.font.family
            font.italic: fontColor.font.italic
            font.pointSize: fontColor.font.pointSize
            font.pixelSize: fontColor.font.pixelSize
            font.weight: fontColor.font.weight
        }

        MouseArea {
            id: mouseArea

            anchors.leftMargin: parent.rightPadding
            anchors.topMargin: parent.topPadding
            anchors.bottomMargin: parent.bottomPadding
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dialogLoader.active = true

            // Color Preview Circle
            Rectangle {
                id: previewBgMask

                visible: false
                anchors.fill: parent
                border.width: 1 * Kirigami.Units.devicePixelRatio
                border.color: "transparent"
                radius: width / 2
            }

            QtGraphicalEffects.ConicalGradient {
                id: previewBgGradient

                visible: fontColor.showPreviewBg
                anchors.fill: parent
                angle: 0
                source: previewBgMask

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "white"
                    }

                    GradientStop {
                        position: 0.24
                        color: "white"
                    }

                    GradientStop {
                        position: 0.25
                        color: "#cccccc"
                    }

                    GradientStop {
                        position: 0.49
                        color: "#cccccc"
                    }

                    GradientStop {
                        position: 0.5
                        color: "white"
                    }

                    GradientStop {
                        position: 0.74
                        color: "white"
                    }

                    GradientStop {
                        position: 0.75
                        color: "#cccccc"
                    }

                    GradientStop {
                        position: 1
                        color: "#cccccc"
                    }

                }

            }

            Rectangle {
                id: previewFill

                anchors.fill: parent
                color: fontColor.valueColor
                border.width: 1 * Kirigami.Units.devicePixelRatio
                border.color: lerpColor(color, Kirigami.Theme.textColor, 0.5)
                // border.color: Kirigami.ColorUtils.linearInterpolation(color, Kirigami.Theme.textColor, 0.5)
                radius: width / 2
            }

        }

        Loader {
            id: dialogLoader

            active: false

            sourceComponent: ColorDialog {
                id: dialog

                visible: false
                modality: Qt.WindowModal
                showAlphaChannel: fontColor.showAlphaChannel
                color: fontColor.valueColor
                onCurrentColorChanged: {
                    if (visible && color != currentColor)
                        fontColor.text = currentColor;

                }
                onVisibleChanged: {
                    if (!visible)
                        dialogLoader.active = false;

                }
                // showAlphaChannel must be set before opening the dialog.
                // If we create the dialog with visible=true, the showAlphaChannelbinding
                // will not be set before it opens.
                Component.onCompleted: visible = true
            }

        }

    }

}
