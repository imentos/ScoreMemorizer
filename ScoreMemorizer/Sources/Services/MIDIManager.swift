import CoreMIDI
import Foundation
import Observation

@Observable

final class MIDIManager: @unchecked Sendable {
    var status = "MIDI not connected"
    var onNoteOn: ((UInt8) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()

    func start() {
        guard client == 0 else { return }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        MIDIClientCreateWithBlock("ScoreMemorizer MIDI Client" as CFString, &client) { [weak self] notification in
            let messageID = notification.pointee.messageID.rawValue
            DispatchQueue.main.async { [weak self] in
                self?.status = "MIDI changed: \(messageID)"
                self?.connectSources()
            }
        }

        MIDIInputPortCreateWithBlock(client, "ScoreMemorizer Input" as CFString, &inputPort) { packetList, _ in
            let manager = Unmanaged<MIDIManager>.fromOpaque(selfPointer).takeUnretainedValue()
            manager.handle(packetList: packetList)
        }

        connectSources()
    }

    private func connectSources() {
        let sourceCount = MIDIGetNumberOfSources()
        guard sourceCount > 0 else {
            status = "No MIDI keyboard found. Use the screen piano."
            return
        }

        for index in 0..<sourceCount {
            let source = MIDIGetSource(index)
            MIDIPortConnectSource(inputPort, source, nil)
        }

        status = "MIDI connected: \(sourceCount) source\(sourceCount == 1 ? "" : "s")"
    }

    private func handle(packetList: UnsafePointer<MIDIPacketList>) {
        var packet = packetList.pointee.packet
        for _ in 0..<packetList.pointee.numPackets {
            let bytes = Mirror(reflecting: packet.data).children.compactMap { $0.value as? UInt8 }
            parse(bytes: Array(bytes.prefix(Int(packet.length))))
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func parse(bytes: [UInt8]) {
        guard bytes.count >= 3 else { return }
        let command = bytes[0] & 0xF0
        let note = bytes[1]
        let velocity = bytes[2]

        if command == 0x90, velocity > 0 {
            DispatchQueue.main.async { [weak self] in
                self?.onNoteOn?(note)
            }
        }
    }
}

