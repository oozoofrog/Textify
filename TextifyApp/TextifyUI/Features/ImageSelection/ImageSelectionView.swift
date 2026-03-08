import SwiftUI
import PhotosUI
import CoreGraphics

struct ImageSelectionView: View {
    @State var viewModel: ImageSelectionViewModel
    let onImageSelected: (CGImage) -> Void

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.isLoading {
                ProgressView("Loading image...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let cgImage = viewModel.selectedImage {
                // Image preview
                Image(decorative: cgImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                // Action buttons
                HStack(spacing: 16) {
                    Button("Change") {
                        viewModel.clearSelection()
                    }
                    .buttonStyle(.bordered)

                    Button("Use This Image") {
                        onImageSelected(cgImage)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Photo picker
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Select an image to convert to text art")
                        .foregroundStyle(.secondary)

                    PhotosPicker(
                        selection: $viewModel.selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("Choose Photo", systemImage: "photo.fill")
                            .font(.headline)
                            .padding()
                            .background(.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .navigationTitle("Select Image")
        .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
            Task {
                await viewModel.loadImage(from: newItem)
            }
        }
    }
}
