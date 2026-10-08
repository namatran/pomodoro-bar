import AVFoundation

/// Google-timer-style alarm: four quick beeps and a pause, looped until stopped.
final class Alarm {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pattern: AVAudioPCMBuffer

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        pattern = Self.makePattern(format: format)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !player.isPlaying else { return }
        // No usable output device: stay silent rather than crash in play().
        guard (try? engine.start()) != nil else { return }
        player.scheduleBuffer(pattern, at: nil, options: .loops)
        player.play()
    }

    func stop() {
        player.stop()
        // Release the audio device between alarms.
        engine.stop()
    }

    /// Four 80 ms beeps at 880 Hz, 70 ms apart, then half a second of silence.
    private static func makePattern(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let beeps = 4, beep = 0.08, slot = 0.15, fade = 0.005
        let frames = AVAudioFrameCount(rate * (Double(beeps) * slot + 0.5))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            let intoSlot = t.truncatingRemainder(dividingBy: slot)
            guard t < Double(beeps) * slot, intoSlot < beep else {
                samples[i] = 0
                continue
            }
            // Short fade in and out so the beep edges don't click.
            let envelope = min(1, intoSlot / fade, (beep - intoSlot) / fade)
            samples[i] = Float(0.4 * envelope * sin(2 * .pi * 880 * t))
        }
        return buffer
    }
}
