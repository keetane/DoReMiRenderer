import DoReMiRendererKit
import SwiftUI

struct ContentView: View {
    @State private var model = ExampleScoreModel.load()
    @State private var showsNoteColor = true
    @State private var showsStaffColor = true
    @State private var showsCurrentNote = true
    @State private var scale: CGFloat = 1
    @State private var selectedNoteID: NoteID?
    @State private var playbackIndex = 0
    @State private var lastHitSummary = "Tap a note or staff line"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                Divider()
                content
            }
            .navigationTitle("DoReMi Renderer")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                Toggle("Note Color", isOn: $showsNoteColor)
                Toggle("Staff Color", isOn: $showsStaffColor)
                Toggle("Current Note", isOn: $showsCurrentNote)
            }
            .toggleStyle(.switch)

            Text(lastHitSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            scaleControls
            playbackControls
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var scaleControls: some View {
        HStack(spacing: 12) {
            Text("Scale \(scale, specifier: "%.1f")x")
                .font(.callout)
                .foregroundStyle(.secondary)

            Picker("Scale", selection: $scale) {
                Text("1.0x").tag(CGFloat(1.0))
                Text("1.5x").tag(CGFloat(1.5))
                Text("2.0x").tag(CGFloat(2.0))
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
        }
    }

    @ViewBuilder
    private var playbackControls: some View {
        if case .loaded(_, _, _, let playbackEvents) = model {
            HStack(spacing: 12) {
                Button("Previous", systemImage: "chevron.left") {
                    movePlaybackStep(by: -1)
                }
                .disabled(playbackEvents.isEmpty || playbackIndex == 0)

                Button("Next", systemImage: "chevron.right") {
                    movePlaybackStep(by: 1)
                }
                .disabled(playbackEvents.isEmpty || playbackIndex >= playbackEvents.count - 1)

                Text(playbackSummary(events: playbackEvents))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model {
        case .loaded(let score, let layout, let currentNoteID, _):
            ScoreCanvasView(
                layout: layout,
                score: score,
                style: style,
                currentNoteID: showsCurrentNote ? (selectedNoteID ?? currentNoteID) : nil,
                scale: scale,
                scrollAxes: [.horizontal, .vertical],
                followsCurrentNote: showsCurrentNote,
                onTap: handleTap
            )
            .frame(maxWidth: .infinity, maxHeight: 720)
            .padding(24)
            .background(Color(.systemBackground))
        case .failed(let message):
            ContentUnavailableView("Unable to load score", systemImage: "exclamationmark.triangle", description: Text(message))
        }
    }

    private var style: ScoreStyle {
        ScoreStyle(
            backgroundColor: .white,
            defaultInkColor: .black,
            staffLineStyle: showsStaffColor
                ? .pitchClass(defaultPalette: defaultEducationalPalette, clefOverrides: [:])
                : .monochrome(.black),
            noteColorStyle: showsNoteColor
                ? .pitchClass(defaultEducationalPalette)
                : .monochrome(.black),
            ledgerLineStyle: showsNoteColor ? .matchNotePitch : .defaultInk,
            accidentalStyle: showsNoteColor ? .matchNotePitch : .defaultInk,
            highlightStyle: HighlightStyle(color: ScoreColor(red: 0.1, green: 0.45, blue: 1.0, alpha: 0.28))
        )
    }

    private func handleTap(_ result: HitTestResult) {
        if let noteID = result.nearestNoteID {
            selectedNoteID = noteID
        }

        let elementText = result.elements.first.map { "\($0.kind)" } ?? "none"
        let nearestText = result.nearestNoteID?.rawValue ?? "nil"
        lastHitSummary = "element: \(elementText)  nearestNoteID: \(nearestText)"

        if let noteID = result.nearestNoteID,
           case .loaded(_, _, _, let playbackEvents) = model,
           let index = playbackEvents.firstIndex(where: { $0.noteIDs.contains(noteID) }) {
            playbackIndex = index
        }
    }

    private func movePlaybackStep(by offset: Int) {
        guard case .loaded(_, _, _, let playbackEvents) = model, !playbackEvents.isEmpty else {
            return
        }
        let nextIndex = min(max(playbackIndex + offset, 0), playbackEvents.count - 1)
        playbackIndex = nextIndex
        selectedNoteID = playbackEvents[nextIndex].noteIDs.first
        lastHitSummary = "playback step: \(nextIndex + 1)/\(playbackEvents.count)"
    }

    private func playbackSummary(events: [PlaybackEvent]) -> String {
        guard !events.isEmpty else {
            return "Step 0/0  note: nil"
        }
        let index = min(playbackIndex, events.count - 1)
        let noteText = events[index].noteIDs.first?.rawValue ?? "nil"
        return "Step \(index + 1)/\(events.count)  note: \(noteText)"
    }
}

private enum ExampleScoreModel {
    case loaded(score: ScoreDocument, layout: ScoreLayout, currentNoteID: NoteID?, playbackEvents: [PlaybackEvent])
    case failed(String)

    static func load() -> ExampleScoreModel {
        guard let url = Bundle.main.url(forResource: "sample_melody", withExtension: "musicxml") else {
            return .failed("sample_melody.musicxml is missing from the app bundle.")
        }

        do {
            let data = try Data(contentsOf: url)
            let renderer = DoReMiRenderer()
            let score = try renderer.parseMusicXML(data: data)
            let layout = try renderer.layout(
                score: score,
                options: LayoutOptions(pageWidth: 980, staffSpace: 16, systemSpacing: 96, measureSpacing: 36)
            )
            let currentNoteID = score.parts
                .flatMap(\.measures)
                .flatMap(\.notes)
                .first(where: { $0.pitch != nil })?
                .id
            let playbackEvents = renderer.makePlaybackSequence(score: score, options: .default)
            return .loaded(score: score, layout: layout, currentNoteID: currentNoteID, playbackEvents: playbackEvents)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
