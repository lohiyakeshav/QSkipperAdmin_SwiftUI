import SwiftUI
import PhotosUI

struct ProductFormView: View {
    // Environment
    @EnvironmentObject private var authService: AuthService
    @Environment(\.presentationMode) private var presentationMode
    @Binding var isPresented: Bool
    
    // Product to edit (nil if adding new)
    var product: Product?
    
    // State
    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
    @State private var category = ""
    @State private var isAvailable = true
    @State private var isFeatured = false
    @State private var extraTime = 0
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Product Name", text: $name)
                    
                    TextField("Category", text: $category)
                        .autocapitalization(.words)
                    
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                        .overlay(
                            Text("Description")
                                .foregroundColor(Color(AppColors.mediumGray))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .opacity(description.isEmpty ? 1 : 0),
                            alignment: .topLeading
                        )
                }
                
                Section(header: Text("Product Image")) {
                    Button(action: {
                        showImagePicker = true
                    }) {
                        HStack {
                            Text("Select Image")
                            Spacer()
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(Color(AppColors.mediumGray))
                                    .frame(width: 80, height: 80)
                                    .background(Color(AppColors.lightGray))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                
                Section(header: Text("Additional Settings")) {
                    Toggle("Available", isOn: $isAvailable)
                    
                    Toggle("Featured Item", isOn: $isFeatured)
                    
                    Stepper("Extra Prep Time: \(extraTime) mins", value: $extraTime, in: 0...60, step: 5)
                }
                
                Section {
                    Button(action: saveProduct) {
                        Text(product == nil ? "Add Product" : "Update Product")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color(AppColors.primaryGreen))
                    .disabled(name.isEmpty || category.isEmpty || price.isEmpty || isLoading)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(Color(AppColors.errorRed))
                            .font(AppFonts.caption)
                    }
                }
                
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(product == nil ? "Add Product" : "Edit Product")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear {
                // Populate form if editing existing product
                if let existingProduct = product {
                    name = existingProduct.name
                    description = existingProduct.description
                    price = String(existingProduct.price)
                    category = existingProduct.category
                    isAvailable = existingProduct.isAvailable
                    isFeatured = existingProduct.isFeatured
                    extraTime = existingProduct.extraTime
                    selectedImage = existingProduct.productPhoto
                }
            }
        }
    }
    
    private func saveProduct() {
        guard let priceValue = Int(price) else {
            errorMessage = "Price must be a valid number"
            return
        }
        
        guard let restaurantId = authService.currentUser?.restaurantId else {
            errorMessage = "Restaurant ID not found"
            return
        }
        
        // Create product model
        var updatedProduct = Product(
            id: product?.id ?? "",
            name: name,
            price: priceValue,
            restaurantId: restaurantId,
            category: category,
            description: description,
            extraTime: extraTime,
            rating: product?.rating ?? 0.0,
            isAvailable: isAvailable,
            isFeatured: isFeatured,
            productPhoto: selectedImage
        )
        
        isLoading = true
        
        Task {
            do {
                // Try multipart method first (better for handling images)
                if product == nil {
                    // Add new product
                    _ = try await ProductApi.shared.createProductWithMultipart(product: updatedProduct, image: selectedImage)
                } else {
                    // Update existing product
                    _ = try await ProductApi.shared.createProductWithMultipart(product: updatedProduct, image: selectedImage)
                }
                
                // Success
                await MainActor.run {
                    isLoading = false
                    errorMessage = nil
                    isPresented = false
                }
            } catch {
                // If multipart fails, try standard method as fallback
                do {
                    if product == nil {
                        // Add new product
                        _ = try await ProductApi.shared.createProduct(product: updatedProduct, image: selectedImage)
                    } else {
                        // Update existing product
                        _ = try await ProductApi.shared.createProduct(product: updatedProduct, image: selectedImage)
                    }
                    
                    // Success
                    await MainActor.run {
                        isLoading = false
                        errorMessage = nil
                        isPresented = false
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

struct ProductFormView_Previews: PreviewProvider {
    static var previews: some View {
        ProductFormView(isPresented: .constant(true))
            .environmentObject(AuthService())
    }
} 