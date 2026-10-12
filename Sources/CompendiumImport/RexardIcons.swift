import CoreGraphics
import Foundation

/// The pictures in the user's Rexard packs, hashed so that Foundry's core icons, most of them Rexard's, can be
/// matched to the user's own copies. Hashes are cached by file size and date, so only new files are read again.
public struct RexardIcons: Sendable {
    /// The folder holding the packs.
    public let folder: URL
    /// Each picture's path in the folder.
    let files: [String]
    /// The words of the hashes of each picture's crops, `ImageHashing.crops.count` hashes per file, one after
    /// another, for a fast search.
    private let words: [UInt64]

    /// Reads the packs' pictures, hashing those the cache doesn't know, and updates the cache.
    public static func load(folder: URL, cache: URL) -> RexardIcons {
        let old = HashCache.read(from: cache)
        let found = pictures(in: folder)
        let entries = parallelMap(found) { file in
            if let entry = old.files[file.path], entry.size == file.size, entry.modified == file.modified {
                return entry
            }
            return HashCache.Entry(size: file.size, modified: file.modified,
                                   hashes: hashes(of: folder.appendingPathComponent(file.path)).map(\.hex))
        }
        let cached = HashCache(files: Dictionary(zip(found.map(\.path), entries)) { first, _ in first })
        cached.write(to: cache)
        return RexardIcons(folder: folder, cache: cached)
    }

    init(folder: URL, cache: HashCache) {
        self.folder = folder
        let usable = cache.files.filter { $0.value.hashes.count == ImageHashing.crops.count }.sorted { $0.key < $1.key }
        files = usable.map(\.key)
        words = usable.flatMap { $0.value.hashes.compactMap(DifferenceHash.init(hex:)).flatMap(\.words) }
    }

    /// The pack picture nearest to the picture at `url`, compared over black and over white; nil when there are
    /// none or the picture can't be read.
    func bestMatch(for url: URL) -> (file: String, distance: Int)? {
        let wanted = [0, 1].compactMap { ImageHashing.gray(of: url, background: $0) }.map { ImageHashing.hash(of: $0) }
        let size = DifferenceHash.wordCount
        guard !wanted.isEmpty, !files.isEmpty, words.count == files.count * ImageHashing.crops.count * size
        else { return nil }
        var best = (index: 0, distance: Int.max)
        words.withUnsafeBufferPointer { words in
            for hash in wanted {
                for index in 0..<words.count / size {
                    var distance = 0
                    for word in 0..<size { distance += (words[index * size + word] ^ hash.words[word]).nonzeroBitCount }
                    if distance < best.distance { best = (index, distance) }
                }
            }
        }
        return (files[best.index / ImageHashing.crops.count], best.distance)
    }

    /// The hashes of a picture's crops over black; empty when it can't be read.
    static func hashes(of url: URL) -> [DifferenceHash] {
        guard let gray = ImageHashing.gray(of: url, background: 0) else { return [] }
        return ImageHashing.crops.map { ImageHashing.hash(of: gray, crop: $0) }
    }

    /// The PNG files under the folder, with their sizes and dates.
    private static func pictures(in folder: URL) -> [PackFile] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys,
                                                              options: [.skipsHiddenFiles]) else { return [] }
        let prefix = folder.standardizedFileURL.path + "/"
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension.lowercased() == "png" }
        return files.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), let size = values.fileSize,
                  let modified = values.contentModificationDate else { return nil }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(prefix) else { return nil }
            return PackFile(path: String(path.dropFirst(prefix.count)), size: size,
                            modified: modified.timeIntervalSinceReferenceDate)
        }
        .sorted { $0.path < $1.path }
    }
}

/// A picture in the packs: its path there, size and date.
private struct PackFile: Sendable {
    var path: String
    var size: Int
    var modified: Double
}

/// The hashes of the pack pictures, by path, as last read.
struct HashCache: Codable {
    struct Entry: Codable {
        var size: Int
        var modified: Double
        var hashes: [String]
    }

    var files: [String: Entry] = [:]

    static func read(from url: URL) -> HashCache {
        guard let data = try? Data(contentsOf: url) else { return HashCache() }
        return (try? JSONDecoder().decode(HashCache.self, from: data)) ?? HashCache()
    }

    /// Writes the cache; a cache that can't be written is only slower next time.
    func write(to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

/// Maps the elements on all cores, keeping their order.
func parallelMap<Element: Sendable, Result: Sendable>(_ elements: [Element],
                                                      _ transform: @Sendable (Element) -> Result) -> [Result] {
    let results = ParallelResults<Result>(count: elements.count)
    DispatchQueue.concurrentPerform(iterations: elements.count) { results.set(transform(elements[$0]), at: $0) }
    return results.values
}

/// Results written by several threads, each to its own index.
private final class ParallelResults<Value: Sendable>: @unchecked Sendable {
    private var storage: [Value?]
    private let lock = NSLock()

    init(count: Int) {
        storage = Array(repeating: nil, count: count)
    }

    var values: [Value] { lock.withLock { storage.compactMap { $0 } } }

    func set(_ value: Value, at index: Int) {
        lock.withLock { storage[index] = value }
    }
}
