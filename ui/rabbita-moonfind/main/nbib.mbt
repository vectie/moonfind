///|
struct NbibField {
  tag : String
  value : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct NbibReference {
  record_number : Int
  pmid : String
  reference_type : String
  title : String
  authors : Array[String]
  editors : Array[String]
  year : String
  venue : String
  keywords : String
  doi : String
  url : String
  abstract_text : String
  fields : Array[NbibField]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct NbibIntake {
  source : BriefInputSource
  references : Array[NbibReference]
  total_count : Int
} derive(Debug, FromJson)

///|
struct NbibSelection {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[NbibReference]
} derive(Debug, FromJson)

///|
struct NbibView {
  intake : NbibIntake?
  author_filter : String
  selected : Array[Int]
}

///|
enum NbibMsg {
  Choose
  FileLoaded(Int, String)
  Imported(Int, Result[Json, Error])
  Filter(String)
  Toggle(Int)
  AddSelected
  Selected(Int, Result[Json, Error])
}

///|
fn empty_nbib_view() -> NbibView {
  { intake: None, author_filter: "", selected: [], }
}

///|
extern "js" fn nbib_lower(value : String) -> String =
  #|value => Array.from(value, ch => ch.toLowerCase()).join('')

///|
fn nbib_filtered(view : NbibView) -> Array[NbibReference] {
  let query = nbib_lower(view.author_filter.trim().to_owned())
  view.intake
  .map(intake => {
    intake.references.filter(reference => {
      query.is_empty() ||
      reference.authors.any(name => nbib_lower(name).contains(query))
    })
  })
  .unwrap_or([])
}

///|
fn update_nbib_view(
  emit : @rabbita.Emit[Msg],
  action : NbibMsg,
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
                emit(BriefAction(Nbib(FileLoaded(generation, raw)))),
              )
            },
            ".nbib",
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
          fail("No PubMed NBIB file selected")
        }
        let sources : Array[BriefInputSource] = @json.from_json(sources)
        if sources.is_empty() {
          return (@rabbita.none, view)
        }
        guard sources.length() == 1 else {
          fail("Import one PubMed NBIB bibliography at a time")
        }
        let generation = view.generation + 1
        (
          @http.post(product_api_url("/api/v1/briefs/nbib/intake"))
          .with_json({ "source": sources[0].to_json(), "author_filter": "" })
          .expect_json(
            emit.map(reply => BriefAction(Nbib(Imported(generation, reply)))),
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
        let intake : NbibIntake = @json.from_json(payload)
        (
          @rabbita.none,
          {
            ..view,
            pending: false,
            nbib: { intake: Some(intake), author_filter: "", selected: [], },
            error: None,
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
    Filter(author_filter) =>
      (@rabbita.none, { ..view, nbib: { ..view.nbib, author_filter, }, })
    Toggle(number) => {
      let selected = if view.nbib.selected.contains(number) {
        view.nbib.selected.filter(item => item != number)
      } else {
        view.nbib.selected + [number]
      }
      (@rabbita.none, { ..view, nbib: { ..view.nbib, selected, }, })
    }
    AddSelected => {
      guard view.nbib.intake is Some(intake) && !view.nbib.selected.is_empty() else {
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
              "PubMed NBIB selection uses two source slots: the original file and the selected card metadata",
            ),
          },
        )
      }
      let generation = view.generation + 1
      (
        @http.post(product_api_url("/api/v1/briefs/nbib/select"))
        .with_json({
          "source": intake.source.to_json(),
          "record_numbers": view.nbib.selected.to_json(),
        })
        .expect_json(
          emit.map(reply => BriefAction(Nbib(Selected(generation, reply)))),
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
            nbib: empty_nbib_view(),
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
  }
}
