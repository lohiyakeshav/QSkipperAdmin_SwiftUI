import SwiftUI
import Combine
import PhotosUI
// Import the UIKitImagePicker
import UIKit

struct ProductsView: View {
    // Environment
    @EnvironmentObject private var dataController: DataController
    @EnvironmentObject private var authService: AuthService
    
    // State
    @State private var isAddProductSheetPresented = false
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showDebugInfo = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and add button
            HStack {
                Text("Products")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Debug info - show restaurant ID being used
                if let restaurantId = UserDefaults.standard.string(forKey: "restaurant_id"), !restaurantId.isEmpty {
                    Text("ID: \(String(restaurantId.suffix(6)))")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                }
                
                // Refresh button with menu
                Menu {
                    Button(action: {
                        loadProducts()
                    }) {
                        Label("Refresh Products", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: {
                        // Clear image cache and reload
                        ProductApi.shared.clearImageCache()
                        loadProducts()
                    }) {
                        Label("Clear Cache & Reload", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .padding(.trailing, 8)
                
                Button(action: {
                    isAddProductSheetPresented = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Product")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            // Main content
            if isLoading {
                Spacer()
                ProgressView("Loading products...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Text("Error loading products")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Debug info button
                    Button(action: { showDebugInfo.toggle() }) {
                        Label(showDebugInfo ? "Hide Debug Info" : "Show Debug Info", systemImage: "info.circle")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    
                    // Debug info
                    if showDebugInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("User ID: \(authService.getUserId() ?? "None")")
                            Text("Is Authenticated: \(authService.isAuthenticated ? "Yes" : "No")")
                            Text("Has Token: \(authService.getToken() != nil ? "Yes" : "No")")
                        }
                        .font(.caption2)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button("Retry") {
                        loadProducts()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                Spacer()
            } else if products.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 70))
                        .foregroundColor(.gray)
                    
                    Text("No Products Yet")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Add your first product to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        isAddProductSheetPresented = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Product")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                    }
                }
                .padding()
                Spacer()
            } else {
                // Product grid
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 300, maximum: 350), spacing: 20)
                        ],
                        spacing: 20
                    ) {
                        ForEach(products) { product in
                            ProductCard(product: product)
                                .contextMenu {
                                    Button(action: {
                                        // Edit product action
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        deleteProduct(product)
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await loadProductsAsync()
                }
            }
        }
        .sheet(isPresented: $isAddProductSheetPresented) {
            // Reload products after dismissing the sheet
            loadProducts()
        } content: {
            AddProductView()
                .environmentObject(dataController)
                .environmentObject(authService)
        }
        .onAppear {
            loadProducts()
        }
    }
    
    private func loadProducts() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Log the start of the product loading process
                DebugLogger.shared.log("Starting to load products", category: .network)
                
                // Use the direct product loading method
                let fetchedProducts = try await ProductApi.shared.getAllProducts()
                DebugLogger.shared.log("Successfully loaded \(fetchedProducts.count) products", category: .network)
                
                // Update on main thread
                await MainActor.run {
                    self.products = fetchedProducts
                    self.isLoading = false
                }
            } catch {
                DebugLogger.shared.logError(error, tag: "PRODUCT_LOADING")
                
                await MainActor.run {
                    self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadProductsAsync() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Use the direct product loading method with proper logging
            DebugLogger.shared.log("Refreshing products (pull-to-refresh)", category: .network)
            let fetchedProducts = try await ProductApi.shared.getAllProducts()
            DebugLogger.shared.log("Refresh completed, loaded \(fetchedProducts.count) products", category: .network)
            
            // Update on main thread
            await MainActor.run {
                self.products = fetchedProducts
                self.isLoading = false
            }
        } catch {
            DebugLogger.shared.logError(error, tag: "PRODUCT_LOADING")
            
            await MainActor.run {
                self.errorMessage = "Failed to refresh products: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func deleteProduct(_ product: Product) {
        Task {
            do {
                // Show loading state
                await MainActor.run {
                    isLoading = true
                }
                
                // Delete the product using ProductApi
                let success = try await ProductApi.shared.deleteProduct(productId: product.id)
                
                if success {
                    // Remove product from the list
                    await MainActor.run {
                        if let index = products.firstIndex(where: { $0.id == product.id }) {
                            products.remove(at: index)
                        }
                        isLoading = false
                    }
                } else {
                    throw NSError(domain: "ProductsView", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to delete product"])
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete product: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// Product Card View for grid display
struct ProductCard: View {
    let product: Product
    @State private var productImage: UIImage? = nil
    @State private var isLoadingImage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Product image or placeholder
            ZStack {
                if isLoadingImage {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(height: 160)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                } else if let image = productImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(height: 160)
                        .overlay(
                            Image(systemName: "cube.fill")
                                .foregroundColor(.gray)
                                .font(.largeTitle)
                        )
                        .onAppear {
                            loadProductImage()
                        }
                }
                
                // Category badge
                VStack {
                    HStack {
                        Spacer()
                        Text(product.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(8)
            }
            .cornerRadius(8)
            
            // Product name and price
            HStack {
                Text(product.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text("₹\(product.price)")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            // Product description
            Text(product.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            // Extra time indicator if applicable
            if product.extraTime > 0 {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Extra preparation: +\(product.extraTime)m")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .frame(maxWidth: .infinity)
        .frame(height: 300) // Fixed height to ensure consistent card sizes
    }
    
    private func loadProductImage() {
        // Use the correct endpoint for product photos
        let imageUrl = "\(NetworkManager.baseURL)/get_product_photo/\(product.id)"
        
        // Delay loading to prevent too many concurrent requests
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.5)) {
            self.loadImage(from: imageUrl)
        }
    }
    
    private func loadImage(from urlString: String) {
        // Skip if already loading
        if isLoadingImage {
            return
        }
        
        isLoadingImage = true
        
        Task {
            do {
                if let url = URL(string: urlString) {
                    DebugLogger.shared.log("Loading image from \(urlString)", category: .network)
                    let image = try await ProductApi.shared.fetchImage(from: url)
                    
                    await MainActor.run {
                        self.productImage = image
                        self.isLoadingImage = false
                    }
                } else {
                    throw ProductApi.ProductApiError.invalidURL
                }
            } catch {
                print("Error loading image: \(error.localizedDescription)")
                
                // Don't keep retrying failed images
                await MainActor.run {
                    self.isLoadingImage = false
                }
            }
        }
    }
}

// Add Product Sheet View
struct AddProductView: View {
    // Environment
    @EnvironmentObject private var dataController: DataController
    @EnvironmentObject private var authService: AuthService
    @Environment(\.presentationMode) private var presentationMode
    
    // State
    @State private var productName: String = ""
    @State private var productPrice: String = ""
    @State private var productCategory: String = ""
    @State private var productDescription: String = ""
    @State private var preparationTime: String = "0"
    @State private var productImage: UIImage? = nil
    @State private var isImagePickerShown = false
    
    // UI state
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Information")) {
                    TextField("Product Name", text: $productName)
                    
                    HStack {
                        Text("₹")
                        TextField("Price", text: $productPrice)
                            .keyboardType(.decimalPad)
                    }
                    
                    TextField("Category", text: $productCategory)
                    
                    HStack {
                        TextField("Extra Time (minutes)", text: $preparationTime)
                            .keyboardType(.numberPad)
                        Text("minutes")
                    }
                }
                
                Section(header: Text("Description")) {
                    TextEditor(text: $productDescription)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("Product Image")) {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            if let image = productImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                            } else {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(height: 200)
                                    .overlay(
                                        Text("No Image Selected")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                    
                    Button(action: {
                        isImagePickerShown = true
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Select Image")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Button(action: submitProduct) {
                        HStack {
                            Spacer()
                            
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            
                            Text("Add Product")
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $isImagePickerShown) {
                UIKitImagePicker(selectedImage: $productImage)
            }
            .alert("Message", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if alertMessage == "Product added successfully" {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func submitProduct() {
        guard validateProductFields() else { return }
        
        isSubmitting = true
        
        // Create product object
        let product = Product(
            name: productName,
            price: Int(Double(productPrice) ?? 0.0),
            restaurantId: authService.getUserId() ?? "",
            category: productCategory,
            description: productDescription,
            extraTime: Int(preparationTime) ?? 0,
            isAvailable: true,
            isActive: true
        )
        
        // Submit product to API
        Task {
            do {
                let _ = try await ProductApi.shared.createProduct(product: product, image: productImage)
                
                await MainActor.run {
                    isSubmitting = false
                    showAlert(message: "Product added successfully")
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    showAlert(message: "Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func validateProductFields() -> Bool {
        // Basic validation
        if productName.isEmpty {
            showAlert(message: "Please enter product name")
            return false
        }
        
        if productPrice.isEmpty {
            showAlert(message: "Please enter product price")
            return false
        }
        
        if productCategory.isEmpty {
            showAlert(message: "Please enter product category")
            return false
        }
        
        if productDescription.isEmpty {
            showAlert(message: "Please enter product description")
            return false
        }
        
        if productImage == nil {
            showAlert(message: "Please select a product image")
            return false
        }
        
        return true
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

 