import SwiftUI

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct PhotoCropView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    // Image with gestures
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSize, height: cropSize)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(dragGesture)
                        .gesture(magnificationGesture)
                        .frame(width: geo.size.width, height: geo.size.height)

                    // Circular mask overlay
                    CircleMaskOverlay(cropSize: cropSize)
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let cropped = cropImage()
                        onSave(cropped)
                        dismiss()
                    }
                    .bold()
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                clampOffset()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = max(1.0, min(newScale, 5.0))
            }
            .onEnded { _ in
                scale = max(1.0, min(scale, 5.0))
                lastScale = scale
                clampOffset()
            }
    }

    private func clampOffset() {
        // Limit panning so the image always covers the crop circle
        let imageSize = cropSize * scale
        let maxOffset = (imageSize - cropSize) / 2

        withAnimation(.easeOut(duration: 0.2)) {
            offset.width = max(-maxOffset, min(maxOffset, offset.width))
            offset.height = max(-maxOffset, min(maxOffset, offset.height))
        }
        lastOffset = offset
    }

    private func cropImage() -> UIImage {
        let imageSize = image.size
        let cropViewSize = cropSize
        let scaledImageSize = cropViewSize * scale

        // Calculate the crop rect in image coordinates
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2

        let imageScale = min(imageSize.width, imageSize.height) / cropViewSize
        let effectiveScale = imageScale / scale

        let offsetXInImage = -offset.width * effectiveScale
        let offsetYInImage = -offset.height * effectiveScale

        let cropSizeInImage = cropViewSize * effectiveScale

        let cropRect = CGRect(
            x: centerX + offsetXInImage - cropSizeInImage / 2,
            y: centerY + offsetYInImage - cropSizeInImage / 2,
            width: cropSizeInImage,
            height: cropSizeInImage
        )

        // Crop
        guard let cgImage = image.cgImage else { return image }

        // Clamp to image bounds
        let clampedRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))
        guard !clampedRect.isEmpty,
              let croppedCG = cgImage.cropping(to: clampedRect) else { return image }

        // Render to a square output
        let outputSize: CGFloat = 400
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { ctx in
            let drawRect = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
            UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
                .draw(in: drawRect)
        }
    }
}

// MARK: - Circle Mask Overlay

struct CircleMaskOverlay: View {
    let cropSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            let rect = geo.size
            Canvas { context, size in
                // Fill the whole area with semi-transparent black
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.black.opacity(0.6))
                )

                // Cut out the circle
                let circleRect = CGRect(
                    x: (rect.width - cropSize) / 2,
                    y: (rect.height - cropSize) / 2,
                    width: cropSize,
                    height: cropSize
                )
                context.blendMode = .destinationOut
                context.fill(
                    Path(ellipseIn: circleRect),
                    with: .color(.white)
                )
            }
            .compositingGroup()

            // Circle border
            Circle()
                .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                .frame(width: cropSize, height: cropSize)
                .position(x: rect.width / 2, y: rect.height / 2)
        }
    }
}
