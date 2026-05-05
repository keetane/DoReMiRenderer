#if os(iOS)
import DoReMiRendererKit
import Foundation
import SwiftUI
import UIKit

@MainActor
enum SnapshotTestSupport {
    static let defaultSize = CGSize(width: 820, height: 260)

    static func renderScore(
        xml: String,
        style: ScoreStyle = fullColorStyle(),
        currentNoteSelector: ((ScoreLayout) -> NoteID?)? = nil
    ) throws -> UIImage {
        let renderer = DoReMiRenderer()
        let score = try renderer.parseMusicXML(data: Data(xml.utf8))
        let layout = try renderer.layout(
            score: score,
            options: LayoutOptions(pageWidth: defaultSize.width, staffSpace: 12)
        )
        let currentNoteIDs = Set([currentNoteSelector?(layout)].compactMap { $0 })
        let view = ScoreCanvasView(
            layout: layout,
            score: score,
            style: style,
            currentNoteIDs: currentNoteIDs
        )
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)

        let rendererView = ImageRenderer(content: view)
        rendererView.scale = 1
        guard let image = rendererView.uiImage else {
            throw SnapshotError.renderFailed
        }
        return image
    }

    static func fullColorStyle() -> ScoreStyle {
        ScoreStyle(
            backgroundColor: .white,
            defaultInkColor: .black,
            staffLineStyle: .pitchClass(defaultPalette: defaultEducationalPalette, clefOverrides: [:]),
            noteColorStyle: .pitchClass(defaultEducationalPalette),
            ledgerLineStyle: .matchNotePitch,
            accidentalStyle: .matchNotePitch
        )
    }

    static func noteColorOffStaffColorOnStyle() -> ScoreStyle {
        ScoreStyle(
            backgroundColor: .white,
            defaultInkColor: .black,
            staffLineStyle: .pitchClass(defaultPalette: defaultEducationalPalette, clefOverrides: [:]),
            noteColorStyle: .monochrome(.black),
            ledgerLineStyle: .defaultInk,
            accidentalStyle: .defaultInk
        )
    }

    static func noteColorOnStaffColorOffStyle() -> ScoreStyle {
        ScoreStyle(
            backgroundColor: .white,
            defaultInkColor: .black,
            staffLineStyle: .monochrome(.black),
            noteColorStyle: .pitchClass(defaultEducationalPalette),
            ledgerLineStyle: .matchNotePitch,
            accidentalStyle: .matchNotePitch
        )
    }
}

enum SnapshotError: Error {
    case renderFailed
}
#endif

