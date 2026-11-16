import SwiftUI
import PhotosUI
import UIKit

/// Optional profile photo. The picked image is downscaled to at most 800 px (ImageIO thumbnail, so very large
/// HEIC and ProRAW files are safe) and stored as JPEG on the resume. Removing it can be undone.
struct PhotoRow: View {
    @Binding var photoData: Data?
    let showsNote: Bool

    @State private var item: PhotosPickerItem?
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    @State private var errorText: String?
    /// The photo that was just removed, kept so "Undo" can put it back.
    @State private var removedPhoto: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            HStack(spacing: CK.Space.m) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                        Text(photoData == nil ? "Add photo" : "Change photo")
                            .font(CK.Font.label)
                            .foregroundStyle(CK.Palette.forest)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .disabled(isLoading)
                    if photoData != nil {
                        EdTextButton(title: "Remove photo", role: .destructive) { removePhoto() }
                            .accessibilityHint("You can undo this right after")
                    }
                }
                Spacer(minLength: 0)
            }
            if removedPhoto != nil, photoData == nil {
                undoBar
            }
            if showsNote {
                Text("The photo only appears on templates that have a photo area. Some employers prefer resumes without one.")
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
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task { await load(newItem) }
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
        .accessibilityLabel(isLoading ? "Loading photo" : (photoData == nil ? "No photo" : "Profile photo"))
    }

    private func removePhoto() {
        removedPhoto = photoData
        errorText = nil
        photoData = nil
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Photo removed. Undo is available."))
    }

    private func load(_ pickerItem: PhotosPickerItem) async {
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
            let result: Result<Data, PhotoProcessor.Failure> = await Task.detached(priority: .userInitiated) {
                PhotoProcessor.process(data)
            }.value
            switch result {
            case .success(let jpeg):
                photoData = jpeg
            case .failure(let failure):
                errorText = failure.message
            }
        } catch {
            errorText = String(localized: "That photo could not be loaded. Try another one.")
        }
    }
}
