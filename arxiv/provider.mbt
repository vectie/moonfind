///|
pub async fn fetch_papers(
  query : String,
  max_results : Int,
  retrieved_at : Int64,
) -> Array[@research.PaperRecord] {
  let url = search_url(query, max_results)
  let headers : Map[String, String] = {
    "User-Agent": "Moonfind/0.1 research@vectie.com",
    "Accept": "application/atom+xml",
  }
  let (response, body) = @http.get(url, headers~)
  guard response.code == 200 else {
    fail("arXiv returned HTTP \{response.code}: \{response.reason}")
  }
  decode_atom_feed(body.text(), retrieved_at)
}
