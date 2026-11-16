import SwiftUI
import PhotosUI

/// Optional profile photo. The picked image is downscaled to at most 600 px and stored as JPEG on the resume.
struct PhotoRow: View {
    @Binding var photoData: Data?
    let showsNote: Bool

    @State private var item: PhotosPickerItem?
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    @State private var errorText: String?

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
                    if photoData != nil {
                        EdTextButton(title: "Remove photo", role: .destructive) { photoData = nil }
                    }
                }
                Spacer(minLength: 0)
            }
            if showsNote {
                Text("The photo only appears on templates that have a photo area. Some employers prefer resumes without one.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
            }
            if let errorText {
                Text(errorText)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.danger)
            }
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task { await load(newItem) }
        }
        .onChange(of: photoData, initial: true) { _, newData in
            if let newData { thumbnail = UIImage(data: newData) } else { thumbnail = nil }
        }
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
        .accessibilityLabel(photoData == nil ? "No photo" : "Profile photo")
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
                errorText = "That photo could not be loaded. Try another one."
                return
            }
            let jpeg: Data? = await Task.detached(priority: .userInitiated) {
                PhotoProcessor.downscaledJPEG(from: data)
            }.value
            if let jpeg {
                photoData = jpeg
            } else {
                errorText = "That image could not be read. Try another photo."
            }
        } catch {
            errorText = "That photo could not be loaded. Try another one."
        }
    }
}
