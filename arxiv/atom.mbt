///|
fn xml_unescape(value : String) -> String {
  value
  .replace_all(old="&amp;", new="&")
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&#39;", new="'")
}

///|
fn normalized_xml_text(value : String) -> String {
  xml_unescape(value)
  .replace_all(old="\n", new=" ")
  .replace_all(old="\r", new=" ")
  .replace_all(old="\t", new=" ")
  .split(" ")
  .filter(fn(part) { !part.is_blank() })
  .join(" ")
}

///|
fn xml_between(source : String, open : String, close : String) -> String? {
  guard source.find(open) is Some(open_index) else { return None }
  let value_start = open_index + open.length()
  let tail = source[value_start:]
  guard tail.find(close) is Some(close_index) else { return None }
  Some(tail[:close_index].to_owned())
}

///|
fn atom_entry_blocks(feed : String) -> Array[String] {
  let entries : Array[String] = []
  let mut cursor = 0
  for ;; {
    let tail = feed[cursor:]
    guard tail.find("<entry>") is Some(relative_start) else { break }
    let start = cursor + relative_start
    let entry_tail = feed[start:]
    guard entry_tail.find("</entry>") is Some(relative_end) else { break }
    let end = start + relative_end + "</entry>".length()
    entries.push(feed[start:end].to_owned())
    cursor = end
  }
  entries
}

///|
fn atom_authors(entry : String) -> Array[String] {
  let authors : Array[String] = []
  let mut cursor = 0
  for ;; {
    let tail = entry[cursor:]
    guard tail.find("<author>") is Some(relative_start) else { break }
    let start = cursor + relative_start
    let author_tail = entry[start:]
    guard author_tail.find("</author>") is Some(relative_end) else { break }
    let block = author_tail[:relative_end + "</author>".length()].to_owned()
    match xml_between(block, "<name>", "</name>") {
      Some(name) => authors.push(normalized_xml_text(name))
      None => ()
    }
    cursor = start + relative_end + "</author>".length()
  }
  authors
}

///|
fn xml_attribute(block : String, name : String) -> String? {
  let marker = name + "=\""
  guard block.find(marker) is Some(index) else { return None }
  let tail = block[index + marker.length():]
  guard tail.find("\"") is Some(end) else { return None }
  Some(tail[:end].to_owned())
}

///|
fn atom_categories(entry : String) -> Array[String] {
  let categories : Array[String] = []
  let mut cursor = 0
  for ;; {
    let tail = entry[cursor:]
    guard tail.find("<category") is Some(relative_start) else { break }
    let start = cursor + relative_start
    let category_tail = entry[start:]
    guard category_tail.find("/>") is Some(relative_end) else { break }
    let block = category_tail[:relative_end + 2].to_owned()
    match xml_attribute(block, "term") {
      Some(category) if !category.is_blank() && !categories.contains(category) =>
        categories.push(category)
      _ => ()
    }
    cursor = start + relative_end + 2
  }
  categories
}

///|
fn arxiv_versionless_id(versioned_id : String) -> String {
  guard versioned_id.rev_find("v") is Some(index) else { return versioned_id }
  let suffix = versioned_id[index + 1:]
  if !suffix.is_empty() && suffix.all(fn(char) { char >= '0' && char <= '9' }) {
    versioned_id[:index].to_owned()
  } else {
    versioned_id
  }
}

///|
fn digest_text(value : String) -> String {
  let bytes = @crypto.sha256(@utf8.encode(value))
  let builder = StringBuilder::new()
  for byte in bytes {
    let code = byte.to_int()
    builder.write_char(lower_hex_digit(code / 16))
    builder.write_char(lower_hex_digit(code % 16))
  }
  "sha256:" + builder.to_string()
}

///|
fn lower_hex_digit(value : Int) -> Char {
  if value < 10 {
    (value + 48).unsafe_to_char()
  } else {
    (value - 10 + 97).unsafe_to_char()
  }
}

///|
fn required_xml_text(entry : String, tag : String) -> String raise {
  match xml_between(entry, "<\{tag}>", "</\{tag}>") {
    Some(value) if !normalized_xml_text(value).is_blank() =>
      normalized_xml_text(value)
    _ => fail("arXiv entry is missing required tag: \{tag}")
  }
}

///|
fn parse_atom_entry(
  entry : String,
  retrieved_at : Int64,
) -> @research.PaperRecord raise {
  let id_url = required_xml_text(entry, "id")
  guard id_url.rev_find("/abs/") is Some(index) else {
    fail("arXiv entry id is not an abstract URL")
  }
  let versioned_id = id_url[index + "/abs/".length():].to_owned()
  let paper_id = arxiv_versionless_id(versioned_id)
  let categories = atom_categories(entry)
  guard !paper_id.is_blank() && !categories.is_empty() else {
    fail("arXiv entry identity or categories are incomplete")
  }
  {
    paper_id,
    versioned_id,
    title: required_xml_text(entry, "title"),
    abstract_text: required_xml_text(entry, "summary"),
    authors: atom_authors(entry),
    categories,
    published_at: required_xml_text(entry, "published"),
    updated_at: required_xml_text(entry, "updated"),
    abs_url: "https://arxiv.org/abs/\{versioned_id}",
    pdf_url: "https://arxiv.org/pdf/\{versioned_id}",
    source_digest: digest_text(entry),
    retrieved_at,
    relevance_score: 0,
    relevance_reasons: [],
  }
}

///|
pub fn decode_atom_feed(
  feed : String,
  retrieved_at : Int64,
) -> Array[@research.PaperRecord] raise {
  guard retrieved_at >= 0 else { fail("retrieved_at must be non-negative") }
  let entries = atom_entry_blocks(feed)
  guard !entries.is_empty() else { fail("arXiv feed contains no entries") }
  entries.map(entry => parse_atom_entry(entry, retrieved_at))
}
