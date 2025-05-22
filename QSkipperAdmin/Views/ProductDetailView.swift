import SwiftUI

struct ProductDetailView: View {
    // Environment
    @EnvironmentObject private var productService: ProductService
    @Environment(\.presentationMode) private var presentationMode
    
    // Product being viewed
    let product: Product
    
    // State
    @State private var showEditSheet = false
    @State private var isShowingDeleteAlert = false
    @State private var isAvailable = false
    @State private var productImage: UIImage? = nil
    @State private var isLoadingImage = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Product image
                ZStack {
                    if isLoadingImage {
                        Rectangle()
                            .fill(Color(AppColors.lightGray))
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    } else if let image = productImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(AppColors.lightGray))
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(Color(AppColors.mediumGray))
                            )
                    }
                }
                .onAppear {
                    loadProductImage()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text(product.name)
                                .font(AppFonts.title)
                                .foregroundColor(Color(AppColors.darkGray))
                            
                            Text(product.category)
                                .font(AppFonts.body)
                                .foregroundColor(Color(AppColors.mediumGray))
                        }
                        
                        Spacer()
                        
                        Text("₹\(product.price)")
                            .font(AppFonts.title)
                            .foregroundColor(Color(AppColors.primaryGreen))
                    }
                    
                    Divider()
                    
                    // Description
                    Text("Description")
                        .font(AppFonts.sectionTitle)
                        .foregroundColor(Color(AppColors.darkGray))
                    
                    Text(product.description.isEmpty ? "No description provided" : product.description)
                        .font(AppFonts.body)
                        .foregroundColor(Color(AppColors.darkGray))
                        .padding(.bottom, 8)
                    
                    // Additional info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Status:")
                                .font(AppFonts.body.bold())
                            
                            Text(product.isAvailable ? "Available" : "Unavailable")
                                .font(AppFonts.body)
                                .foregroundColor(product.isAvailable ? 
                                                 Color(AppColors.primaryGreen) : 
                                                 Color(AppColors.errorRed))
                        }
                        
                        HStack {
                            Text("Extra Prep Time:")
                                .font(AppFonts.body.bold())
                            
                            Text("\(product.extraTime) minutes")
                                .font(AppFonts.body)
                        }
                        
                        if product.isFeatured {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(Color.yellow)
                                
                                Text("Featured Item")
                                    .font(AppFonts.body.bold())
                                    .foregroundColor(Color.yellow)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Availability toggle
                    Toggle("Available for Order", isOn: $isAvailable)
                        .toggleStyle(SwitchToggleStyle(tint: Color(AppColors.primaryGreen)))
                        .font(AppFonts.body.bold())
                        .padding(.vertical, 8)
                        .onChange(of: isAvailable) { newValue in
                            updateAvailability(newValue)
                        }
                    
                    // Action buttons
                    HStack {
                        Button(action: {
                            showEditSheet = true
                        }) {
                            Text("Edit")
                                .font(AppFonts.buttonText)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(AppColors.primaryGreen))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            isShowingDeleteAlert = true
                        }) {
                            Text("Delete")
                                .font(AppFonts.buttonText)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(AppColors.errorRed))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.top, 16)
                }
                .padding()
            }
        }
        .navigationTitle("Product Details")
        .sheet(isPresented: $showEditSheet) {
            ProductFormView(isPresented: $showEditSheet, product: product)
                .environmentObject(productService)
        }
        .alert(isPresented: $isShowingDeleteAlert) {
            Alert(
                title: Text("Delete Product"),
                message: Text("Are you sure you want to delete this product? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteProduct()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            isAvailable = product.isAvailable
        }
    }
    
    private func updateAvailability(_ available: Bool) {
        // Create a mutable copy of the product
        var updatedProduct = product
        updatedProduct.isAvailable = available
        
        Task {
            do {
                // Update the product using the API
                let _ = try await ProductApi.shared.createProduct(product: updatedProduct)
                print("Updated availability to: \(available)")
            } catch {
                // Revert the toggle on error
                await MainActor.run {
                    isAvailable = !available
                    print("Failed to update availability: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteProduct() {
        Task {
            do {
                // Delete the product using the API
                let success = try await ProductApi.shared.deleteProduct(productId: product.id)
                
                if success {
                    // Go back to product list on main thread
                    await MainActor.run {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } catch {
                print("Failed to delete product: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadProductImage() {
        isLoadingImage = true
        
        // Use the correct endpoint for product photos
        let imageUrlString = "\(NetworkManager.baseURL)/get_product_photo/\(product.id)"
        
        guard let url = URL(string: imageUrlString) else {
            isLoadingImage = false
            return
        }
        
        Task {
            do {
                let image = try await ProductApi.shared.fetchImage(from: url)
                
                await MainActor.run {
                    self.productImage = image
                    self.isLoadingImage = false
                }
            } catch {
                print("Error loading product image: \(error.localizedDescription)")
                await MainActor.run {
                    // If there's a product photo in memory, use that
                    if let photoFromProduct = product.productPhoto {
                        self.productImage = photoFromProduct
                    }
                    self.isLoadingImage = false
                }
            }
        }
    }
}

struct ProductDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProductDetailView(product: Product(
                id: "123",
                name: "Cheese Pizza",
                price: 12,
                restaurantId: "",
                category: "Pizza",
                description: "Delicious cheese pizza with our signature tomato sauce and premium mozzarella cheese.",
                extraTime: 15,
                rating: 4.5,
                isAvailable: true,
                isFeatured: true
            ))
            .environmentObject(ProductService())
        }
    }
} 