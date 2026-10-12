///|
/// A local bibliography card, not evidence that the cited full text was read.
pub(all) struct BibtexReferenceV1 {
  record_number : Int
  citation_key : String
  reference_type : String
  title : String
  authors : Array[String]
  year : String
  venue : String
  keywords : String
  doi : String
  url : String
  abstract_text : String
  availability : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BibtexSelectionV1 {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[BibtexReferenceV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
priv struct BibtexReader {
  chars : Array[Char]
  mut pos : Int
  macros : Map[String, String]
}

///|
fn BibtexReader::peek(self : BibtexReader) -> Char {
  self.chars.get(self.pos).unwrap_or('\u0000')
}

///|
fn bibtex_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\uFEFF'
}

///|
fn BibtexReader::skip(self : BibtexReader) -> Unit {
  while self.pos < self.chars.length() {
    if bibtex_space(self.peek()) {
      self.pos += 1
    } else if self.peek() == '%' {
      while self.pos < self.chars.length() && self.peek() != '\n' {
        self.pos += 1
      }
    } else {
      break
    }
  }
}

///|
fn BibtexReader::expect(self : BibtexReader, ch : Char) -> Unit raise {
  self.skip()
  guard self.peek() == ch else {
    fail("BibTeX: expected '\{ch}' at character \{self.pos + 1}")
  }
  self.pos += 1
}

///|
fn BibtexReader::word(self : BibtexReader) -> String raise {
  self.skip()
  let start = self.pos
  while self.pos < self.chars.length() &&
        !bibtex_space(self.peek()) &&
        !['{', '}', '(', ')', ',', '=', '#', '"', '%'].contains(self.peek()) {
    self.pos += 1
  }
  guard self.pos > start else {
    fail("BibTeX: expected a name or citation key at character \{start + 1}")
  }
  String::from_iter(self.chars[start:self.pos].iter())
}

///|
// Preserve nested groups and TeX escapes as source text. No TeX is executed.
fn BibtexReader::group(self : BibtexReader, quoted : Bool) -> String raise {
  self.pos += 1
  let out = StringBuilder()
  let mut depth = 0
  while self.pos < self.chars.length() {
    let ch = self.peek()
    self.pos += 1
    if ch == '\\' {
      out.write_char(ch)
      if self.pos < self.chars.length() {
        out.write_char(self.peek())
        self.pos += 1
      }
    } else if quoted && ch == '"' && depth == 0 {
      return out.to_string()
    } else if !quoted && ch == '}' && depth == 0 {
      return out.to_string()
    } else {
      if ch == '{' {
        depth += 1
      }
      if ch == '}' {
        guard depth > 0 else { fail("BibTeX: unmatched brace in quoted value") }
        depth -= 1
      }
      out.write_char(ch)
    }
  }
  fail("BibTeX: unfinished quoted or braced value")
}

///|
fn BibtexReader::value(self : BibtexReader) -> String raise {
  let out = StringBuilder()
  while true {
    self.skip()
    let part = match self.peek() {
      '{' => self.group(false)
      '"' => self.group(true)
      _ => {
        let name = self.word()
        if name.iter().all(ch => ch >= '0' && ch <= '9') {
          name
        } else {
          guard self.macros.get(name.to_lower()) is Some(value) else {
            fail(
              "BibTeX: undefined string macro '\{name}'; define it with @string or quote the value",
            )
          }
          value
        }
      }
    }
    out.write_string(part)
    self.skip()
    if self.peek() != '#' {
      break
    }
    self.pos += 1
  }
  out.to_string().trim().to_owned()
}

///|
fn bibtex_authors(value : String) -> Array[String] {
  let chars = value.iter().collect()
  let authors : Array[String] = []
  let mut current = StringBuilder()
  let mut depth = 0
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if ch == '\\' && index + 1 < chars.length() {
      current.write_char(ch)
      current.write_char(chars[index + 1])
      index += 2
      continue
    }
    if ch == '{' {
      depth += 1
    }
    if ch == '}' {
      depth -= 1
    }
    if depth == 0 &&
      index + 3 < chars.length() &&
      index > 0 &&
      bibtex_space(chars[index - 1]) &&
      String::from_iter(chars[index:index + 3].iter()).to_lower() == "and" &&
      bibtex_space(chars[index + 3]) {
      let author = current.to_string().trim().to_owned()
      if !author.is_empty() {
        authors.push(author)
      }
      current = StringBuilder()
      index += 3
    } else {
      current.write_char(ch)
      index += 1
    }
  }
  let author = current.to_string().trim().to_owned()
  if !author.is_empty() {
    authors.push(author)
  }
  authors
}

///|
/// Parse common BibTeX/BibLaTeX exports: nested braced/quoted values, numeric
/// values, @string macros, # concatenation, comments and preambles. Citation
/// keys remain exact. Unknown fields remain in the retained original file.
pub fn parse_bibtex(text : String) -> Array[BibtexReferenceV1] raise {
  let reader : BibtexReader = {
    chars: text.iter().collect(),
    pos: 0,
    macros: {
      "jan": "January",
      "feb": "February",
      "mar": "March",
      "apr": "April",
      "may": "May",
      "jun": "June",
      "jul": "July",
      "aug": "August",
      "sep": "September",
      "oct": "October",
      "nov": "November",
      "dec": "December",
    },
  }
  let references : Array[BibtexReferenceV1] = []
  let keys : Map[String, Bool] = {}
  while true {
    reader.skip()
    if reader.pos == reader.chars.length() {
      break
    }
    reader.expect('@')
    let kind = reader.word().to_lower()
    reader.skip()
    let close = match reader.peek() {
      '{' => '}'
      '(' => ')'
      _ => fail("BibTeX: entry needs '{' or '('")
    }
    if kind == "comment" && reader.peek() == '{' {
      ignore(reader.group(false))
      continue
    }
    reader.pos += 1
    if kind == "comment" {
      let mut depth = 1
      while reader.pos < reader.chars.length() && depth > 0 {
        if reader.peek() == '(' {
          depth += 1
        }
        if reader.peek() == ')' {
          depth -= 1
        }
        reader.pos += 1
      }
      guard depth == 0 else { fail("BibTeX: unfinished comment") }
      continue
    }
    if kind == "preamble" || kind == "string" {
      if kind == "string" {
        let name = reader.word().to_lower()
        reader.expect('=')
        let value = reader.value()
        reader.macros[name] = value
      } else {
        ignore(reader.value())
      }
      reader.skip()
      if reader.peek() == ',' {
        reader.pos += 1
      }
      reader.expect(close)
      continue
    }
    let key = reader.word()
    guard !keys.contains(key) else {
      fail("BibTeX: duplicate citation key '\{key}'")
    }
    keys[key] = true
    let fields : Map[String, String] = {}
    reader.skip()
    if reader.peek() != close {
      reader.expect(',')
    }
    while true {
      reader.skip()
      if reader.peek() == close {
        reader.pos += 1
        break
      }
      let field = reader.word().to_lower()
      reader.expect('=')
      fields[field] = reader.value()
      reader.skip()
      if reader.peek() != close {
        reader.expect(',')
      }
    }
    let title = fields.get("title").unwrap_or("")
    let abstract_text = fields.get("abstract").unwrap_or("")
    let date = fields.get("date").unwrap_or("")
    let year = fields
      .get("year")
      .unwrap_or(if date.length() >= 4 { date[:4].to_owned() } else { date })
    references.push({
      record_number: references.length() + 1,
      citation_key: key,
      reference_type: kind,
      title: if title.is_blank() {
        "Untitled reference " + key
      } else {
        title
      },
      authors: bibtex_authors(fields.get("author").unwrap_or("")),
      year,
      venue: fields
      .get("journal")
      .unwrap_or(
        fields
        .get("journaltitle")
        .unwrap_or(fields.get("booktitle").unwrap_or("")),
      ),
      keywords: fields.get("keywords").unwrap_or(""),
      doi: fields.get("doi").unwrap_or(""),
      url: fields.get("url").unwrap_or(""),
      abstract_text,
      availability: if abstract_text.is_blank() {
        "metadata-only"
      } else {
        "metadata-and-abstract"
      },
    })
  }
  guard !references.is_empty() else { fail("No BibTeX references found") }
  references
}

///|
/// Search citation key, title, authors, year, venue and keywords without
/// renumbering the original records. An empty query returns every card.
pub fn filter_bibtex(
  references : Array[BibtexReferenceV1],
  query : String,
) -> Array[BibtexReferenceV1] {
  fn lower(value : String) -> String {
    String::from_iter(value.iter().map(@unicode.to_lowercase))
  }
  let query = lower(query.trim().to_owned())
  references.filter(reference => {
    lower(
      [
        reference.citation_key,
        reference.title,
        reference.authors.join("; "),
        reference.year,
        reference.venue,
        reference.keywords,
      ].join(" "),
    ).contains(query)
  })
}
