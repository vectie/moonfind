///|
pub fn version() -> String {
  "0.1.0"
}

///|
pub fn product_id() -> String {
  "moonfind"
}

///|
pub fn product_home(workspace : String, book_id : String) -> String {
  "\{workspace}/.moonsuite/products/moonfind/books/\{book_id}"
}
