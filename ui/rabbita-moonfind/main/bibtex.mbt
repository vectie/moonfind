///|
struct BibtexReference {
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
struct BibtexIntake {
  source : BriefInputSource
  references : Array[BibtexReference]
  total_count : Int
} derive(Debug, FromJson)

///|
struct BibtexSelection {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[BibtexReference]
} derive(Debug, FromJson)

///|
struct BibtexView {
  intake : BibtexIntake?
  query : String
  selected : Array[Int]
}

///|
enum BibtexMsg {
  Choose
  FileLoaded(Int, String)
  Imported(Int, Result[Json, Error])
  Filter(String)
  Toggle(Int)
  AddSelected
  Selected(Int, Result[Json, Error])
}

///|
fn empty_bibtex_view() -> BibtexView {
  { intake: None, query: "", selected: [], }
}

///|
extern "js" fn bibtex_lower(value : String) -> String =
  #|value => Array.from(value, ch => ch.toLowerCase()).join('')

///|
fn bibtex_filtered(view : BibtexView) -> Array[BibtexReference] {
  let query = bibtex_lower(view.query.trim().to_owned())
  view.intake
  .map(intake => {
    intake.references.filter(reference => {
      query.is_empty() ||
      bibtex_lower(
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
  })
  .unwrap_or([])
}

///|
fn update_bibtex_view(
  emit : @rabbita.Emit[Msg],
  action : BibtexMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  match action {
    Choose | Filter(_) | Toggle(_) | AddSelected if view.pending =>
      (@rabbita.none, view)
    Choose => {
      let generation = view.generation
      (
        @cmd.custom_cmd(scheduler => {
          brief_choose_files(
            raw => {
              scheduler.add(
                emit(BriefAction(Bibtex(FileLoaded(generation, raw)))),
              )
            },
            ".bib",
            false,
          )
        }),
        view,
      )
    }
    FileLoaded(generation, _) if generation != view.generation || view.pending =>
      (@rabbita.none, view)
    FileLoaded(_, raw) =>
      try {
        let payload = @json.parse(raw)
        if payload is { "error": String(message), .. } {
          fail(message)
        }
        guard payload is { "sources": sources, .. } else {
          fail("No BIBTEX file selected")
        }
        let sources : Array[BriefInputSource] = @json.from_json(sources)
        if sources.is_empty() {
          return (@rabbita.none, view)
        }
        guard sources.length() == 1 else {
          fail("Import one BIBTEX bibliography at a time")
        }
        let generation = view.generation + 1
        (
          @http.post(product_api_url("/api/v1/briefs/bibtex/intake"))
          .with_json({ "source": sources[0].to_json(), "query": "" })
          .expect_json(
            emit.map(reply => BriefAction(Bibtex(Imported(generation, reply)))),
          ),
          { ..view, generation, pending: true, error: None, },
        )
      } catch {
        error => (@rabbita.none, { ..view, error: Some("\{error}"), })
      }
    Imported(generation, _) | Selected(generation, _) if generation !=
      view.generation ||
      !view.pending => (@rabbita.none, view)
    Imported(_, Err(error)) | Selected(_, Err(error)) =>
      (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
    Imported(_, Ok(payload)) =>
      try {
        if brief_reply_error(payload) is Some(message) {
          fail(message)
        }
        let intake : BibtexIntake = @json.from_json(payload)
        (
          @rabbita.none,
          {
            ..view,
            pending: false,
            bibtex: { intake: Some(intake), query: "", selected: [], },
            error: None,
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
    Filter(query) =>
      (@rabbita.none, { ..view, bibtex: { ..view.bibtex, query, }, })
    Toggle(number) => {
      let selected = if view.bibtex.selected.contains(number) {
        view.bibtex.selected.filter(item => item != number)
      } else {
        view.bibtex.selected + [number]
      }
      (@rabbita.none, { ..view, bibtex: { ..view.bibtex, selected, }, })
    }
    AddSelected => {
      guard view.bibtex.intake is Some(intake) &&
        !view.bibtex.selected.is_empty() else {
        return (
          @rabbita.none,
          { ..view, error: Some("Select at least one reference card"), },
        )
      }
      guard view.draft.sources.length() <= 6 else {
        return (
          @rabbita.none,
          {
            ..view,
            error: Some(
              "BIBTEX selection uses two source slots: the original file and the selected card metadata",
            ),
          },
        )
      }
      let generation = view.generation + 1
      (
        @http.post(product_api_url("/api/v1/briefs/bibtex/select"))
        .with_json({
          "source": intake.source.to_json(),
          "record_numbers": view.bibtex.selected.to_json(),
        })
        .expect_json(
          emit.map(reply => BriefAction(Bibtex(Selected(generation, reply)))),
        ),
        { ..view, generation, pending: true, error: None, },
      )
    }
    Selected(_, Ok(payload)) =>
      try {
        if brief_reply_error(payload) is Some(message) {
          fail(message)
        }
        let sources : Array[BriefInputSource] = @json.from_json(payload)
        (
          @rabbita.none,
          {
            ..brief_edited(view, {
              ..view.draft,
              sources: view.draft.sources + sources,
            }),
            pending: false,
            bibtex: empty_bibtex_view(),
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
  }
}
