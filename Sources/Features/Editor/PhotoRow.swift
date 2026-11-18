import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

/// An image waiting in the crop sheet.
struct PhotoCropSource: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Optional profile photo. A photo picked from Photos or Files is decoded at a working size (ImageIO thumbnail,
/// so very large HEIC and ProRAW files are safe), cropped to a square in `PhotoCropSheet`, then stored as a JPEG
/// of at most 800 px on the resume. Removing it can be undone.
struct PhotoRow: View {
    @Binding var photoData: Data?
    let showsNote: Bool
    /// Shape the crop sheet previews first.
    var previewShape: PhotoShape = .circle

    @State private var item: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var cropSource: PhotoCropSource?
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    @State private var errorText: String?
    /// The photo that was just removed, kept so "Undo" can put it back.
    @State private var removedPhoto: Data?

    /// Working size for cropping. The stored photo is reduced to `PhotoProcessor.maxDimension` after the crop.
    private static let cropWorkingSize: CGFloat = 1600

    private static var photoTemplateCount: Int {
        TemplateLibrary.all.filter { $0.supportsPhoto }.count
    }

    private var photoNote: String {
        let count: Int = Self.photoTemplateCount
        return String(localized: "Your photo shows on the \(count) templates marked Photo. Templates without a photo area keep it hidden. Employers in some countries prefer resumes without a photo.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            HStack(spacing: CK.Space.m) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Menu {
                        Button {
                            showPhotosPicker = true
                        } label: {
                            Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Choose from Files", systemImage: "folder")
                        }
                    } label: {
                        Text(photoData == nil ? String(localized: "Add photo") : String(localized: "Change photo"))
                            .font(CK.Font.label)
                            .foregroundStyle(CK.Palette.forest)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .disabled(isLoading)
                    .accessibilityHint("Choose a photo from Photos or Files, then crop it")
                    if photoData != nil {
                        EdTextButton(title: String(localized: "Adjust crop")) { recrop() }
                        EdTextButton(title: String(localized: "Remove photo"), role: .destructive) { removePhoto() }
                            .accessibilityHint("You can undo this right after")
                    }
                }
                Spacer(minLength: 0)
            }
            if removedPhoto != nil, photoData == nil {
                undoBar
            }
            if showsNote {
                Text(photoNote)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let errorText {
                Text(errorText)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $item, matching: .images, photoLibrary: .shared())
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType.image], allowsMultipleSelection: false) { result in
            handleFile(result)
        }
        .sheet(item: $cropSource) { source in
            PhotoCropSheet(image: source.image, initialCircle: previewShape == .circle) { cropped in
                Task { await store(cropped) }
            }
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task { await loadPicked(newItem) }
        }
        .onChange(of: photoData, initial: true) { _, newData in
            if let newData {
                thumbnail = PhotoProcessor.previewImage(from: newData)
                removedPhoto = nil
            } else {
                thumbnail = nil
            }
        }
    }

    private var undoBar: some View {
        HStack(spacing: CK.Space.s) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CK.Palette.graphite)
                .accessibilityHidden(true)
            Text("Photo removed")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.ink)
            Spacer(minLength: CK.Space.s)
            Button {
                if let removedPhoto { photoData = removedPhoto }
                removedPhoto = nil
            } label: {
                Text("Undo")
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.forest)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Undo remove photo")
        }
        .padding(.leading, CK.Space.m)
        .padding(.trailing, CK.Space.xs)
        .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.stone))
        .accessibilityElement(children: .contain)
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(CK.Palette.stone)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else if isLoading {
                ProgressView()
            } else {
                Image(systemName: "person")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(CK.Palette.graphite)
            }
        }
        .frame(width: 64, height: 64)
        .overlay(Circle().strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLoading ? String(localized: "Loading photo") : (photoData == nil ? String(localized: "No photo") : String(localized: "Profile photo")))
    }

    // MARK: Actions

    private func removePhoto() {
        removedPhoto = photoData
        errorText = nil
        photoData = nil
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Photo removed. Undo is available."))
    }

    /// Opens the crop sheet on the stored photo.
    private func recrop() {
        guard let data = photoData, let image = UIImage(data: data) else { return }
        cropSource = PhotoCropSource(image: image)
    }

    private func loadPicked(_ pickerItem: PhotosPickerItem) async {
        isLoading = true
        errorText = nil
        defer {
            isLoading = false
            item = nil
        }
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                errorText = String(localized: "That photo could not be loaded. Try another one.")
                return
            }
            await prepareCrop(data)
        } catch {
            errorText = String(localized: "That photo could not be loaded. Try another one.")
        }
    }

    private func handleFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            errorText = String(localized: "That file could not be opened. Try another one.")
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped: Bool = url.startAccessingSecurityScopedResource()
            defer {
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
            // Refuse an oversized file before it is read into memory (the file is no longer mapped lazily).
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize, size > PhotoProcessor.maxInputBytes {
                errorText = PhotoProcessor.Failure.tooLarge.message
                return
            }
            // Not memory mapped: access to the file ends when this function returns, while the photo is still
            // being processed on another thread (same rule as the PDF importer).
            guard let data = try? Data(contentsOf: url) else {
                errorText = String(localized: "That file could not be opened. Try another one.")
                return
            }
            Task { await prepareCrop(data) }
        }
    }

    /// Decodes the picked file at a working size and opens the crop sheet.
    private func prepareCrop(_ data: Data) async {
        isLoading = true
        errorText = nil
        let working: CGFloat = Self.cropWorkingSize
        let result: Result<Data, PhotoProcessor.Failure> = await Task.detached(priority: .userInitiated) {
            PhotoProcessor.process(data, maxDimension: working)
        }.value
        isLoading = false
        switch result {
        case .success(let jpeg):
            guard let image = UIImage(data: jpeg) else {
                errorText = PhotoProcessor.Failure.unreadable.message
                return
            }
            cropSource = PhotoCropSource(image: image)
        case .failure(let failure):
            errorText = failure.message
        }
    }

    /// Stores the cropped square as a JPEG of at most 800 px.
    private func store(_ cropped: UIImage) async {
        guard let raw = cropped.jpegData(compressionQuality: 0.95) else {
            errorText = PhotoProcessor.Failure.unreadable.message
            return
        }
        let result: Result<Data, PhotoProcessor.Failure> = await Task.detached(priority: .userInitiated) {
            PhotoProcessor.process(raw)
        }.value
        switch result {
        case .success(let jpeg):
            photoData = jpeg
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Photo added."))
        case .failure(let failure):
            errorText = failure.message
        }
    }
}
