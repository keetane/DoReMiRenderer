import DoReMiRendererKit
import Foundation

enum LibrarySourceType: String, Codable, Hashable {
    case sample
    case imported
}

struct DiagnosticsSummary: Codable, Hashable {
    var errors: Int
    var warnings: Int
    var infos: Int
    var codes: [String]

    init(diagnostics: [RendererDiagnostic]) {
        var errors = 0
        var warnings = 0
        var infos = 0
        for diagnostic in diagnostics {
            switch diagnostic.severity {
            case .error:
                errors += 1
            case .warning:
                warnings += 1
            case .info:
                infos += 1
            }
        }
        self.errors = errors
        self.warnings = warnings
        self.infos = infos
        self.codes = Array(Set(diagnostics.map(\.code))).sorted()
    }
}

struct LibraryItem: Codable, Hashable, Identifiable {
    var id: UUID
    var displayName: String
    var sourceType: LibrarySourceType
    var sourceIdentifier: String
    var lastOpenedAt: Date
    var bookmarkData: Data?
    var diagnosticsSummary: DiagnosticsSummary?
    var lastCurrentNoteIDRawValue: String?
    var lastZoomScale: Double?

    static func sample(from sample: SampleScoreItem, openedAt: Date = Date()) -> LibraryItem {
        LibraryItem(
            id: sample.id,
            displayName: sample.displayName,
            sourceType: .sample,
            sourceIdentifier: sample.sourceIdentifier,
            lastOpenedAt: openedAt,
            bookmarkData: nil,
            diagnosticsSummary: nil,
            lastCurrentNoteIDRawValue: nil,
            lastZoomScale: nil
        )
    }

    static func imported(
        displayName: String,
        sourceURL: URL,
        openedAt: Date,
        bookmarkData: Data?,
        diagnosticsSummary: DiagnosticsSummary?,
        currentNoteID: NoteID?,
        zoomScale: Double?
    ) -> LibraryItem {
        LibraryItem(
            id: UUID(),
            displayName: displayName,
            sourceType: .imported,
            sourceIdentifier: Self.importedSourceIdentifier(for: sourceURL),
            lastOpenedAt: openedAt,
            bookmarkData: bookmarkData,
            diagnosticsSummary: diagnosticsSummary,
            lastCurrentNoteIDRawValue: currentNoteID?.rawValue,
            lastZoomScale: zoomScale
        )
    }

    static func importedSourceIdentifier(for url: URL) -> String {
        "imported:\(url.standardizedFileURL.path)"
    }
}

struct SampleScoreItem: Codable, Hashable, Identifiable {
    var id: UUID
    var displayName: String
    var resourceName: String
    var fileExtension: String

    var sourceIdentifier: String {
        "sample:\(resourceName).\(fileExtension)"
    }

    func url(in bundle: Bundle) -> URL? {
        bundle.url(forResource: resourceName, withExtension: fileExtension)
    }
}

struct SampleScoreCatalog: Hashable {
    var samples: [SampleScoreItem]

    static let `default` = SampleScoreCatalog(samples: [
        SampleScoreItem(
            id: UUID(uuidString: "30E5CC5D-0508-588C-89F7-83EB65B1ECB1")!,
            displayName: "Ode to Joy Easy Variation",
            resourceName: "Ode_to_Joy_Easy_variation",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "38D8E4E4-F798-5EAD-9075-77AEBF0D2A89")!,
            displayName: "Fur Elise - Beginner Piano",
            resourceName: "Fur_Elise_-_Beethoven_-_for_beginner_piano",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "ED7BB9F6-8A0B-5E6D-9BB5-D978D01463B3")!,
            displayName: "12 Variations of Twinkle Twinkle Little Star",
            resourceName: "12_Variations_of_Twinkle_Twinkle_Little_Star",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "284E04A0-EA1C-594F-977A-63A04F66A1CA")!,
            displayName: "Arabesque L. 66 No. 1 in E Major",
            resourceName: "Arabesque_L._66_No._1_in_E_Major",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "779B8E47-E0A0-5D64-B492-7ED64C95DDC7")!,
            displayName: "Ave Maria D839 - Schubert - Solo Piano Arrg.",
            resourceName: "Ave_Maria_D839_-_Schubert_-_Solo_Piano_Arrg.",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "3AB262F4-02F9-5391-AACD-4878DD5C53ED")!,
            displayName: "Bach Minuet in G Major BWV Anh. 114",
            resourceName: "Bach_Minuet_in_G_Major_BWV_Anh._114",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "BB01DE80-16BE-5BC3-B465-6AAB508BFCC9")!,
            displayName: "Bach Toccata and Fugue in D Minor Piano solo",
            resourceName: "Bach_Toccata_and_Fugue_in_D_Minor_Piano_solo",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "6D0B4C4C-5F74-5019-8838-A1823A10BC59")!,
            displayName: "Beethoven Symphony No. 5 1st movement Piano solo",
            resourceName: "Beethoven_Symphony_No._5_1st_movement_Piano_solo",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "0240667F-3B0F-5C23-88F2-25A1AE7F8BF3")!,
            displayName: "Bella Ciao",
            resourceName: "Bella_Ciao",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "DE6E91C7-C954-55C3-ADDE-9A70BEBAC6C4")!,
            displayName: "Canon in D",
            resourceName: "Canon_in_D",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "C404F820-F5B7-50E2-A27C-C54AC91F8383")!,
            displayName: "Canon in D easy",
            resourceName: "Canon_in_D_easy",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "AD6EB28F-DDE8-5F26-8572-F4FC205D90DF")!,
            displayName: "Carol of the Bells",
            resourceName: "Carol_of_the_Bells",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "EED929AE-C09E-529D-B1E9-3F2D67C78821")!,
            displayName: "Carol of the Bells easy piano",
            resourceName: "Carol_of_the_Bells_easy_piano",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "76782411-C83B-51CA-B134-FC87AE4FA829")!,
            displayName: "Chopin - Ballade no. 1 in G minor Op. 23",
            resourceName: "Chopin_-_Ballade_no._1_in_G_minor_Op._23",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "C7299A42-F50A-5689-8CAA-63A9D384463C")!,
            displayName: "Chopin - Nocturne Op. 9 No. 1",
            resourceName: "Chopin_-_Nocturne_Op._9_No._1",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "BD73C7C5-16F0-5795-BC07-D76998131CD2")!,
            displayName: "Chopin - Nocturne Op 9 No 2 E Flat Major",
            resourceName: "Chopin_-_Nocturne_Op_9_No_2_E_Flat_Major",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "94CB2F04-985B-5D90-B853-79E65FD3BD16")!,
            displayName: "Clair de Lune Debussy",
            resourceName: "Clair_de_Lune__Debussy",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "2DC57C12-A472-52A5-95B1-CB56B9C313B3")!,
            displayName: "Clair de lune - Claude Debussy",
            resourceName: "Clair_de_lune_-_Claude_Debussy",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "C652160A-2320-5A65-A216-D05FA5A00460")!,
            displayName: "Dance of the sugar plum fairy",
            resourceName: "Dance_of_the_sugar_plum_fairy",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "46B8D30A-B09A-5135-B2FD-E3D3FF365DD3")!,
            displayName: "Erik Satie - Gymnopedie No.1",
            resourceName: "Erik_Satie_-_Gymnopedie_No.1",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "193D4B27-AFEC-53FA-B63B-7F06C73DBA72")!,
            displayName: "Flight of the Bumblebee",
            resourceName: "Flight_of_the_Bumblebee",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "4B382BA1-F9A7-5455-A50A-80C687D5BE51")!,
            displayName: "Fur Elise",
            resourceName: "Fur_Elise",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "2AB63100-3862-5DCF-BFEC-29C5D117B4BD")!,
            displayName: "Fur Elise Easy Piano",
            resourceName: "Fur_Elise_Easy_Piano",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "B958919A-7477-5A48-B0A8-3D46C232EC47")!,
            displayName: "G Minor Bach Original",
            resourceName: "G_Minor_Bach_Original",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "13AB2842-79E4-5395-B6B4-ECBFED1FE9FB")!,
            displayName: "Gnossienne No. 1",
            resourceName: "Gnossienne_No._1",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "87ADAEE1-85A2-5747-B84F-D7D19B557169")!,
            displayName: "Greensleeves for Piano easy and beautiful",
            resourceName: "Greensleeves_for_Piano_easy_and_beautiful",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "3B1E9D6F-EDB8-5165-A042-A70904E0DD91")!,
            displayName: "Gymnopdie No. 1 Satie",
            resourceName: "Gymnopdie_No._1__Satie",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "6BE672B1-97D0-5FFB-8466-42591CFDE28D")!,
            displayName: "Happy Birthday To You C Major",
            resourceName: "Happy_Birthday_To_You_C_Major",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "FBDCCD81-44D9-5092-902D-8B76A9915B86")!,
            displayName: "Happy Birthday To You Piano",
            resourceName: "Happy_Birthday_To_You_Piano",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "0A135FB9-83B7-5AF3-8245-C83EB24E14A4")!,
            displayName: "Hungarian Dance No 5 in G Minor",
            resourceName: "Hungarian_Dance_No_5_in_G_Minor",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "D5F08905-9BF9-502A-B862-D44D356ECA3E")!,
            displayName: "J. S. Bach - Air on the G String Piano arrangement",
            resourceName: "J._S._Bach_-_Air_on_the_G_String_Piano_arrangement",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "64773097-D8C5-5DDB-A657-34C9F55F590F")!,
            displayName: "La Campanella - Grandes Etudes de Paganini No. 3 - Franz Liszt",
            resourceName: "La_Campanella_-_Grandes_Etudes_de_Paganini_No._3_-_Franz_Liszt",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "4310E73C-C550-55B9-9391-4816995BF297")!,
            displayName: "Lacrimosa - Requiem",
            resourceName: "Lacrimosa_-_Requiem",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "917B638E-21C6-5B6A-A919-E9A4BF84CF4A")!,
            displayName: "Liebestraum No. 3 in A Major",
            resourceName: "Liebestraum_No._3_in_A_Major",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "36FBBFCB-89FA-59C9-A428-51B3BE9894F3")!,
            displayName: "Maple Leaf Rag Scott Joplin",
            resourceName: "Maple_Leaf_Rag_Scott_Joplin",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "B1C2D1E7-6488-5E19-AAAC-658BB992C681")!,
            displayName: "Minuet in G Major Bach",
            resourceName: "Minuet_in_G_Major_Bach",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "5E876156-9298-55C9-A141-1FB890F63454")!,
            displayName: "Mozart - Piano Sonata No. 16 - Allegro",
            resourceName: "Mozart_-_Piano_Sonata_No._16_-_Allegro",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "94EAA65E-72AD-51AD-8E5A-5945D794B853")!,
            displayName: "Nocturne No. 20 in C Minor",
            resourceName: "Nocturne_No._20_in_C_Minor",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "4819994A-8598-5188-B494-9042121A2809")!,
            displayName: "Nocturne in C sharp Minor",
            resourceName: "Nocturne_in_C_sharp_Minor",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "B33CDE7B-6952-5A52-9B9E-2EAFA025DC35")!,
            displayName: "Nocturne in E-flat Major Op. 9 No. 2 Easy",
            resourceName: "Nocturne_in_E-flat_Major_Op._9_No._2_Easy",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "165F981B-1B4C-517E-AE60-1B0A041D51FD")!,
            displayName: "Passacaglia",
            resourceName: "Passacaglia",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "2BEE1B44-714F-5D45-AAD3-6D27DA5CCE7B")!,
            displayName: "Passacaglia2",
            resourceName: "Passacaglia2",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "426B0A44-8FF7-5744-AC57-E2A9AE31B8FD")!,
            displayName: "Piano Sonata No. 11 K. 331 3rd Movement Rondo alla Turca",
            resourceName: "Piano_Sonata_No._11_K._331_3rd_Movement_Rondo_alla_Turca",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "AFCD16B6-70AC-5820-84D1-4FF46AE2786F")!,
            displayName: "Prelude I in C major BWV 846 - Well Tempered Clavier First Book",
            resourceName: "Prelude_I_in_C_major_BWV_846_-_Well_Tempered_Clavier_First_Book",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "2EF3BAE4-1ACC-5B8D-BBF4-24095EE1439D")!,
            displayName: "Prelude No. 2 BWV 847 in C Minor",
            resourceName: "Prelude_No._2_BWV_847_in_C_Minor",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "232A815E-DBEC-5CCC-BD99-F5E534D91FCC")!,
            displayName: "Prlude No. 4 in E Minor Op. 28 - Frdric Chopin",
            resourceName: "Prlude_No._4_in_E_Minor_Op._28_-_Frdric_Chopin",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "AF9F8036-A76A-5B0C-855A-99354B88A526")!,
            displayName: "Prlude Opus 28 No. 4 in E Minor Chopin",
            resourceName: "Prlude_Opus_28_No._4_in_E_Minor__Chopin",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "2D7E3E09-A0F0-5A42-8451-6BF283C636A6")!,
            displayName: "Schubert Serenade - Standchen - By Lizst",
            resourceName: "Schubert_Serenade_-_Standchen_-_By_Lizst",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "5C4A5C1F-0066-5BAB-9EED-DC8A29EC90C0")!,
            displayName: "Sonata No. 16 1st Movement K. 545",
            resourceName: "Sonata_No._16_1st_Movement_K._545",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "D32C50D5-5381-5F6E-8539-C48C625087CF")!,
            displayName: "Sonate No. 14 Moonlight 1st Movement",
            resourceName: "Sonate_No._14_Moonlight_1st_Movement",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "B1F0EAD0-D070-5A03-9697-4CDB0F5F5F07")!,
            displayName: "Sonate No. 14 Moonlight 3rd Movement",
            resourceName: "Sonate_No._14_Moonlight_3rd_Movement",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "952596CC-2689-56F9-B4C3-3DA14EEA0EE3")!,
            displayName: "Sonate No. 8 Pathetique 2nd Movement",
            resourceName: "Sonate_No._8_Pathetique_2nd_Movement",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "E2EFF827-A5DA-51FE-8359-CCE0EA5F2AFC")!,
            displayName: "Swan Lake",
            resourceName: "Swan_Lake",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "47C31CA5-9F58-51C4-930A-C47C38301F5B")!,
            displayName: "The Entertainer - Scott Joplin",
            resourceName: "The_Entertainer_-_Scott_Joplin",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "84CA7505-30E0-5CBE-9DF2-203AD1D5C56F")!,
            displayName: "The Entertainer - Scott Joplin - 1902",
            resourceName: "The_Entertainer_-_Scott_Joplin_-_1902",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "7993B9AC-EA23-5B64-B8A0-81A52303C776")!,
            displayName: "WA Mozart Marche Turque Turkish March fingered",
            resourceName: "WA_Mozart_Marche_Turque_Turkish_March_fingered",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "E2EC34DF-5822-5E05-8BF4-B601E57E742A")!,
            displayName: "Waltz Opus 64 No. 2 in C Minor",
            resourceName: "Waltz_Opus_64_No._2_in_C_Minor",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "1C7350C0-69A7-564B-986A-41DBB0FD264B")!,
            displayName: "Waltz in A MinorChopin",
            resourceName: "Waltz_in_A_MinorChopin",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "EC2C1F2E-361B-558F-80CA-C3E6D1631FAA")!,
            displayName: "Waltz of the Flowers",
            resourceName: "Waltz_of_the_Flowers",
            fileExtension: "mxl"
        ),
        SampleScoreItem(
            id: UUID(uuidString: "45407C76-AA36-5F79-9C2F-83D7F7EB6FD9")!,
            displayName: "moonlight sonata 3rd movement",
            resourceName: "moonlight_sonata_3rd_movement",
            fileExtension: "mxl"
        )
    ])

    var defaultSample: SampleScoreItem? {
        samples.first
    }

    func libraryItems(openedAt: Date = Date(timeIntervalSince1970: 0)) -> [LibraryItem] {
        samples.map { LibraryItem.sample(from: $0, openedAt: openedAt) }
    }
}

struct LibraryCollection: Hashable {
    var sampleItems: [LibraryItem]
    var importedItems: [LibraryItem]

    var allItems: [LibraryItem] {
        sampleItems + importedItems.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    mutating func upsertImported(_ item: LibraryItem) {
        guard item.sourceType == .imported else {
            return
        }
        if let index = importedItems.firstIndex(where: { $0.sourceIdentifier == item.sourceIdentifier }) {
            var updated = item
            updated.id = importedItems[index].id
            importedItems[index] = updated
        } else {
            importedItems.append(item)
        }
    }

    mutating func removeImported(id: UUID) {
        importedItems.removeAll { $0.id == id }
    }
}

struct LibraryResolvedFile {
    var url: URL
    var securityScoped: Bool
    var bookmarkDataIsStale: Bool
}

protocol LibraryFileResolving {
    func resolveFile(for item: LibraryItem) throws -> LibraryResolvedFile
}

struct SecurityScopedLibraryFileResolver: LibraryFileResolving {
    func resolveFile(for item: LibraryItem) throws -> LibraryResolvedFile {
        guard let bookmarkData = item.bookmarkData else {
            throw PaletteImportError.missingLibraryFile(item.displayName)
        }

        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw PaletteImportError.missingLibraryFile(item.displayName)
            }
            return LibraryResolvedFile(url: url, securityScoped: true, bookmarkDataIsStale: stale)
        } catch let error as PaletteImportError {
            throw error
        } catch {
            throw PaletteImportError.missingLibraryFile(item.displayName)
        }
    }
}

struct LibraryStore {
    private struct Payload: Codable {
        var importedItems: [LibraryItem]
    }

    var fileURL: URL

    static let `default` = LibraryStore(
        fileURL: FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("DoReMiPalette", isDirectory: true)
            .appendingPathComponent("library.json")
    )

    func loadImportedItems() -> [LibraryItem] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        do {
            return try JSONDecoder.paletteLibrary.decode(Payload.self, from: data).importedItems
        } catch {
            return []
        }
    }

    func saveImportedItems(_ importedItems: [LibraryItem]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.paletteLibrary.encode(Payload(importedItems: importedItems))
        try data.write(to: fileURL, options: [.atomic])
    }
}

private extension JSONEncoder {
    static var paletteLibrary: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var paletteLibrary: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
