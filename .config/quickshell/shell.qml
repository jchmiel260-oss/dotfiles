import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "Theme" as Theme

PanelWindow {
    id: root

	property real cpuPerc: 0

	property int batteryPerc: 0

	property int volumePerc: 0

    property real memUsed: 0
	property real memTotal: 1
	property real swapUsed: 0
	property real swapTotal: 1
	readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0
	readonly property real swapPerc: swapTotal > 0 ? swapUsed / swapTotal : 0

    property real lastCpuIdle: 0
	property real lastCpuTotal: 0

    property string batteryStatus: ""
    property bool volumeMuted: false
    property bool networkConnected: false
    property string networkName: ""
    property real networkSignal: 0

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 30
    color: Theme.Colors.colBg

    Component.onCompleted: {
        updateCpu();
        updateMemory();
        updateBattery();
        updateVolume();
        updateNetwork();
        updateTimer.start();
    }

    function updateCpu() {
		cpuProcess.running = true;
	}

	function updateMemory() {
		memProcess.running = true;
	}

	function updateBattery() {
		batteryProcess.running = true;
	}

	function updateVolume() {
		volumeProcess.running = true;
	}

	function updateNetwork() {
		networkProcess.running = true;
	}

	Process {
		id: cpuProcess
		command: ["/bin/sh", "-c", "cat /proc/stat | grep '^cpu '"]
		running: false

		stdout: SplitParser {
			onRead: data => {
				const parts = data.trim().split(/\s+/);

				if (parts.length >= 5) {
					const user = parseInt(parts[1]);
					const nice = parseInt(parts[2]);
					const system = parseInt(parts[3]);
					const idle = parseInt(parts[4]);
					const total = user + nice + system + idle;

					if (lastCpuTotal > 0) {
						const totalDiff = total - lastCpuTotal;
						const idleDiff = idle - lastCpuIdle;

						if (totalDiff > 0) {
							cpuPerc = 1 - (idleDiff / totalDiff);
						}
					}

					lastCpuIdle = idle;
					lastCpuTotal = total;
				}
			}
		}
	}

	Process {
		id: batteryProcess
		command: ["/bin/sh", "-c", "printf \"%s %s\" " + "$(cat /sys/class/power_supply/BAT0/capacity) " + "$(cat /sys/class/power_supply/BAT0/status)"]
		running: false

		stdout: SplitParser {
			onRead: data => {
				const parts = data.trim().split(" ");

				if (parts.length >= 2) {
					batteryPerc = parseInt(parts[0]);
					batteryStatus = parts[1];
				}
			}
		}
	}

	Process {
		id: volumeProcess
		command: ["/bin/sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
		running: false

		stdout: SplitParser {
			onRead: data => {
				// Example output:
				// Volume: 0.42
				// Volume: 0.42 [MUTED]

				const parts = data.trim().split(" ");

				if (parts.length >= 2) {
					const vol = parseFloat(parts[1]);
					volumePerc = Math.round(vol * 100);
					volumeMuted = data.includes("[MUTED]");
				}
			}
		}
	}

	Process {
		id: networkProcess
		command: ["/bin/sh", "-c", "nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi | grep '^yes' | cut -d: -f2,3"]
		running: false

		stdout: SplitParser {
			onRead: data => {
				const output = data.trim();

				if (output.length > 0) {
					const parts = output.split(":");
					const name = parts[0];
					const signal = parts[1];

					networkName = name;
					networkSignal = signal;
					networkConnected = true;
				} else {
					networkName = "Offline";
					networkSignal = "0";
					networkConnected = false;
				}
			}
		}
	}

	Process {
		id: memProcess
		command: ["/bin/sh", "-c", "free -b"]
		running: false

		stdout: SplitParser {
			onRead: data => {
				const lines = data.trim().split("\n");

				for (const line of lines) {
					const parts = line.trim().split(/\s+/);

					if (parts[0] === "Mem:") {
						memTotal = parseInt(parts[1]);
						memUsed  = parseInt(parts[2]);
					}

					if (parts[0] === "Swap:") {
						swapTotal = parseInt(parts[1]);
						swapUsed  = parseInt(parts[2]);
					}
				}
			}
		}
	}	

	Timer {
		id: updateTimer
		interval: 430
		repeat: true

		onTriggered: {
			updateCpu();
			updateMemory();
			updateBattery();
			updateVolume();
			updateNetwork();
		}
	}

	// apps
	Process {
		id: nmConProcess
		command: ["/usr/bin/alacritty", "-e", "/usr/local/bin/bnmtui"]
		running: false
	}

	Process {
		id: taskManProcess
		command: ["/usr/bin/alacritty", "-e", "btop"]
		running: false
	}

	Process {
		id: ramCleanProcess
		command: ["sudo", "/usr/local/bin/drop-caches"]
		running: false
	}

	RowLayout {
		anchors.fill: parent
		anchors.margins: 8
		spacing: 8

		// // // // // //
		//    LEFT     //
		// // // // // //
		Repeater {
			model: 9

			Text {
				property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
				property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)

				text: index + 1
				color: isActive ? Theme.Colors.colCyan : (ws ? Theme.Colors.colFg : Theme.Colors.colMuted)

				font {
					family: Theme.Typography.fontFamily
					pixelSize: Theme.Typography.fontSize
					bold: true
				}

				MouseArea {
					anchors.fill: parent
					onClicked: Hyprland.dispatch("workspace " + (index + 1))
				}
			}
		}

		Item {
			Layout.fillWidth: true
		}
		// // // // // //
		//     MID	   //
		// // // // // //


		// RIGHT
		Item {
			Layout.fillWidth: true
		}




		// ---------------- CLOCK ----------------
		Text {
			id: clock
			color: Theme.Colors.colBlue

			font.family: Theme.Typography.fontFamily
			font.pixelSize: Theme.Typography.fontSize
			font.bold: true

			property date curDate: new Date()
			property var icons: ["󱑊","󱐿","󱑀","󱑁","󱑂","󱑃",
			"󱑄","󱑅","󱑆","󱑇","󱑈","󱑉"]

			text: icons[curDate.getHours() % 12] + " " +
			Qt.formatDateTime(curDate, "HH:mm:ss")

			Timer {
				interval: 1000
				running: true
				repeat: true
				onTriggered: clock.curDate = new Date()
			}
		}

		Rectangle { width: 1; height: 16; color: Theme.Colors.colMuted }

		// ---------------- NETWORK ----------------	
		Item {
			id: networkItem
			implicitWidth: networkLabel.implicitWidth 
			implicitHeight: networkLabel.implicitHeight 
			Text {
				id: networkLabel
				anchors.centerIn: parent 
				property string netIcon: { 
					if (!networkConnected) return "󰤭 "; 
					if (networkSignal >= 90) return "󰤨 "; // 100% 
					if (networkSignal >= 70) return "󰤥 "; // 70% 
					if (networkSignal >= 50) return "󰤢 "; // 50% 
					if (networkSignal >= 10) return "󰤟 "; // 10% return "󰤯 "; // 0% 
				} 
				text: networkConnected 
				? netIcon + networkName 
				: netIcon + "Offline" 
				color: networkConnected ? Theme.Colors.colGreen : Theme.Colors.colRed 
				font { 
					family: Theme.Typography.fontFamily 
					pixelSize: Theme.Typography.fontSize 
					bold: true 
				} 
			} 
			MouseArea { 
				anchors.fill: parent 
				hoverEnabled: true 
				cursorShape: Qt.PointingHandCursor 
				onClicked: { 
					nmConProcess.running = true; 
				} 
			} 
		}

		Rectangle { width: 1; height: 16; color: Theme.Colors.colMuted }

		// ---------------- VOLUME ----------------
		Text {
			text: volumeMuted
			? " MUTE"
			: " " + volumePerc + "%"

			color: volumeMuted ? Theme.Colors.colRed
			: Theme.Colors.colFg

			font.family: Theme.Typography.fontFamily
			font.pixelSize: Theme.Typography.fontSize
			font.bold: true
		}

		Rectangle { width: 1; height: 16; color: Theme.Colors.colMuted }

		// ---------------- BATTERY ----------------
		Text {
			text: {
				let icon = " ";
				if (batteryPerc >= 90) icon = " ";
				else if (batteryPerc >= 70) icon = " ";
				else if (batteryPerc >= 50) icon = " ";
				else if (batteryPerc >= 10) icon = " ";
				return icon + batteryPerc + "%";
			}

			color: batteryStatus === "Charging"
			? Theme.Colors.colGreen
			: batteryPerc <= 20
			? Theme.Colors.colRed
			: Theme.Colors.colFg

			font.family: Theme.Typography.fontFamily
			font.pixelSize: Theme.Typography.fontSize
			font.bold: true
		}

		Rectangle { width: 1; height: 16; color: Theme.Colors.colMuted }

		// ---------------- CPU ----------------
		Item {
			id: cpuItem
			implicitWidth: cpuLabel.implicitWidth 
			implicitHeight: cpuLabel.implicitHeight

			Text {
				id: cpuLabel
				anchors.centerIn: parent
				text: " " + Math.round(cpuPerc * 100) + "%"

				color: cpuPerc >= 0.8
				? Theme.Colors.colRed
				: cpuPerc >= 0.35
				? Theme.Colors.colOrange
				: Theme.Colors.colFg

				font.family: Theme.Typography.fontFamily
				font.pixelSize: Theme.Typography.fontSize
				font.bold: true
			}

			MouseArea { 
				anchors.fill: parent 
				hoverEnabled: true 
				cursorShape: Qt.PointingHandCursor 
				onClicked: { 
					taskManProcess.running = true;
				} 
			}
		}
		Rectangle { width: 1; height: 16; color: Theme.Colors.colMuted }

		// ---------------- RAM ----------------
		Item {
			id: ramItem
			implicitWidth: ramLabel.implicitWidth 
			implicitHeight: ramLabel.implicitHeight
			Text {
				id: ramLabel
				anchors.centerIn: parent

				text: "󰑭 " +
				((memUsed + swapUsed) / 1073741824).toFixed(1) + "GB (" +
				Math.round(((memUsed + swapUsed) / (memTotal + swapTotal)) * 100) + "%)"	

				color: Theme.Colors.colCyan
				font.family: Theme.Typography.fontFamily
				font.pixelSize: Theme.Typography.fontSize
				font.bold: true
			}

			MouseArea {
				anchors.fill: parent 
				hoverEnabled: true 
				cursorShape: Qt.PointingHandCursor 
				onClicked: { 
					ramCleanProcess.running = true;
				}
			}
		}
		Rectangle { width: 1; height: 16; color: Theme.Colors.colMuted }


		// ---------------- TRAY ----------------
		Row {
			spacing: 6

			Repeater {
				model: SystemTray.items

				delegate: Item {
					width: 18
					height: 18

					Image {
						anchors.fill: parent
						source: modelData.icon
						fillMode: Image.PreserveAspectFit
					}

					MouseArea {
						anchors.fill: parent
						onClicked: modelData.activate()
						acceptedButtons: Qt.LeftButton | Qt.RightButton
						onPressed: {
							if (mouse.button === Qt.RightButton)
							modelData.openContextMenu();
						}
					}
				}
			}

		}
	}
}
