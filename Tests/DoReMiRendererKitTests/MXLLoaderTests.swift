import Foundation
import Testing
import ZIPFoundation
@testable import DoReMiRendererKit

@Test func parseValidMXLFixture() throws {
    let mxlData = try makeMXLArchive(entries: [
        "META-INF/container.xml": containerXML(rootfilePath: "score.musicxml"),
        "score.musicxml": mxlMusicXML,
    ])

    let score = try DoReMiRenderer().parse(input: .mxlData(mxlData))

    let notes = score.parts.flatMap(\.measures).flatMap(\.notes)
    #expect(score.parts.first?.name == "MXL Fixture")
    #expect(notes.map(\.pitch) == [
        Pitch(step: .c, octave: 4),
        Pitch(step: .d, octave: 4),
    ])
}

@Test func parseMXLWithoutContainerFails() throws {
    let mxlData = try makeMXLArchive(entries: [
        "score.musicxml": mxlMusicXML,
    ])

    do {
        _ = try DoReMiRenderer().parseMXL(data: mxlData)
        Issue.record("Expected missing container.xml to fail")
    } catch let error as MXLLoaderError {
        #expect(error.diagnostic.code == "mxl.missingContainer")
    }
}

@Test func parseMXLWithoutRootfileFails() throws {
    let mxlData = try makeMXLArchive(entries: [
        "META-INF/container.xml": """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles/>
        </container>
        """,
    ])

    do {
        _ = try DoReMiRenderer().parseMXL(data: mxlData)
        Issue.record("Expected missing rootfile to fail")
    } catch let error as MXLLoaderError {
        #expect(error.diagnostic.code == "mxl.missingRootfile")
    }
}

@Test func parseMXLWithInvalidContainerFails() throws {
    let mxlData = try makeMXLArchive(entries: [
        "META-INF/container.xml": "<container><rootfiles>",
    ])

    do {
        _ = try DoReMiRenderer().parseMXL(data: mxlData)
        Issue.record("Expected invalid container.xml to fail")
    } catch let error as MXLLoaderError {
        #expect(error.diagnostic.code == "mxl.invalidContainer")
    }
}

@Test func parseMXLWithMissingRootfileTargetFails() throws {
    let mxlData = try makeMXLArchive(entries: [
        "META-INF/container.xml": containerXML(rootfilePath: "missing.musicxml"),
    ])

    do {
        _ = try DoReMiRenderer().parseMXL(data: mxlData)
        Issue.record("Expected rootfile not found to fail")
    } catch let error as MXLLoaderError {
        #expect(error.diagnostic.code == "mxl.rootfileNotFound")
    }
}

@Test func parseInvalidMXLZipFails() throws {
    do {
        _ = try DoReMiRenderer().parseMXL(data: Data("not a zip archive".utf8))
        Issue.record("Expected invalid zip to fail")
    } catch let error as MXLLoaderError {
        #expect(error.diagnostic.code == "mxl.invalidZip")
    }
}

@Test func parseMusicXMLDataInputStillUsesExistingParser() throws {
    let score = try DoReMiRenderer().parse(input: .musicXMLData(Data(mxlMusicXML.utf8)))

    #expect(score.parts.first?.name == "MXL Fixture")
    #expect(score.parts.flatMap(\.measures).flatMap(\.notes).count == 2)
}

private func makeMXLArchive(entries: [String: String]) throws -> Data {
    let archive = try Archive(accessMode: .create)
    for (path, contents) in entries {
        let data = Data(contents.utf8)
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate
        ) { position, size in
            data.subdata(in: Data.Index(position)..<Data.Index(position) + size)
        }
    }
    return try #require(archive.data)
}

private func containerXML(rootfilePath: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="\(rootfilePath)" media-type="application/vnd.recordare.musicxml+xml"/>
      </rootfiles>
    </container>
    """
}

private let mxlMusicXML = """
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>MXL Fixture</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>1</staff>
      </note>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration><voice>1</voice><staff>1</staff>
      </note>
    </measure>
  </part>
</score-partwise>
"""
