
// use serde::{Serialize, Deserialize};
//
// #[derive(Debug, Serialize, Deserialize)]
// struct User {
//     _id: ObjectId,
//     name: String,
//     email: String,
// }
//
// #[derive(Debug, Serialize, Deserialize)]
// struct Product {
//     _id: ObjectId,
//     name: String,
//     description: String,
//     price: f64,
// }
//
// #[derive(Debug)]
// struct StoreServiceImpl {
//     users_collection: Collection<User>,
//     products_collection: Collection<Product>,
// }
//
// #[tonic::async_trait]
// impl StoreService for StoreServiceImpl {
//     // async fn create_user(
//     //     &self,
//     //     request: Request<CreateUserRequest>,
//     // ) -> Result<Response<UserResponse>, Status> {
//     //     let req = request.into_inner();
//     //     let user = User {
//     //         _id: ObjectId::new(),
//     //         name: req.name,
//     //         email: req.email,
//     //     };
//     //
//     //     self.users_collection
//     //         .insert_one(user, None)
//     //         .await
//     //         .map_err(|e| Status::internal(format!("MongoDB error: {}", e))?;
//     //
//     //     Ok(Response::new(UserResponse {
//     //         id: user._id.to_hex(),
//     //         name: req.name,
//     //         email: req.email,
//     //     }))
//     // }
//     //
//     // async fn get_user(
//     //     &self,
//     //     request: Request<GetUserRequest>,
//     // ) -> Result<Response<UserResponse>, Status> {
//     //     let id = request.into_inner().id;
//     //     let oid = ObjectId::parse_str(&id).map_err(|_| Status::invalid_argument("Invalid ID"))?;
//     //
//     //     let user = self.users_collection
//     //         .find_one(doc! { "_id": oid }, None)
//     //         .await
//     //         .map_err(|e| Status::internal(format!("MongoDB error: {}", e)))?
//     //         .ok_or_else(|| Status::not_found("User not found"))?;
//     //
//     //     Ok(Response::new(UserResponse {
//     //         id: user._id.to_hex(),
//     //         name: user.name,
//     //         email: user.email,
//     //     }))
//     // }
//     //
//     // async fn create_product(
//     //     &self,
//     //     request: Request<CreateProductRequest>,
//     // ) -> Result<Response<ProductResponse>, Status> {
//     //     let req = request.into_inner();
//     //     let product = Product {
//     //         _id: ObjectId::new(),
//     //         name: req.name,
//     //         description: req.description,
//     //         price: req.price as f64,
//     //     };
//     //
//     //     self.products_collection
//     //         .insert_one(product, None)
//     //         .await
//     //         .map_err(|e| Status::internal(format!("MongoDB error: {}", e)))?;
//     //
//     //     Ok(Response::new(ProductResponse {
//     //         id: product._id.to_hex(),
//     //         name: req.name,
//     //         description: req.description,
//     //         price: req.price,
//     //     }))
//     // }
//     //
//     // async fn get_product(
//     //     &self,
//     //     request: Request<GetProductRequest>,
//     // ) -> Result<Response<ProductResponse>, Status> {
//     //     let id = request.into_inner().id;
//     //     let oid = ObjectId::parse_str(&id).map_err(|_| Status::invalid_argument("Invalid ID"))?;
//     //
//     //     let product = self.products_collection
//     //         .find_one(doc! { "_id": oid }, None)
//     //         .await
//     //         .map_err(|e| Status::internal(format!("MongoDB error: {}", e)))?
//     //         .ok_or_else(|| Status::not_found("Product not found"))?;
//     //
//     //     Ok(Response::new(ProductResponse {
//     //         id: product._id.to_hex(),
//     //         name: product.name,
//     //         description: product.description,
//     //         price: product.price,
//     //     }))
//     // }
// }
//
#[derive(Debug, Default)]
struct GameBlocServiceState {
    profile_store: Collection<Booking>,
    tournament_store: Collection<Dog>,
    squad_store: Collection<Owner>,
    games_store: Collection<Owner>,
    notification_store: Collection<Owner>,
    message_store: Collection<Owner>,
    daily_reward_store: Collection<Owner>,
    referral_map: Collection<Owner>,
}
