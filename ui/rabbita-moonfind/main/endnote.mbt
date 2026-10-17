///|
struct EndnoteField {
  tag : String
  value : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct EndnoteReference {
  record_number : Int
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
  fields : Array[EndnoteField]
} derive(Debug, Eq, ToJson, FromJson)

///|
struct EndnoteIntake {
  source : BriefInputSource
  references : Array[EndnoteReference]
  total_count : Int
} derive(Debug, FromJson)

///|
struct EndnoteSelection {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[EndnoteReference]
} derive(Debug, FromJson)

///|
struct EndnoteView {
  intake : EndnoteIntake?
  author_filter : String
  selected : Array[Int]
}

///|
enum EndnoteMsg {
  Choose
  FileLoaded(Int, String)
  Imported(Int, Result[Json, Error])
  Filter(String)
  Toggle(Int)
  AddSelected
  Selected(Int, Result[Json, Error])
}

///|
fn empty_endnote_view() -> EndnoteView {
  { intake: None, author_filter: "", selected: [], }
}

///|
extern "js" fn endnote_lower(value : String) -> String =
  #|value => Array.from(value, ch => ch.toLowerCase()).join('')

///|
fn endnote_filtered(view : EndnoteView) -> Array[EndnoteReference] {
  let query = endnote_lower(view.author_filter.trim().to_owned())
  view.intake
  .map(intake => {
    intake.references.filter(reference => {
      query.is_empty() ||
      reference.authors.any(name => endnote_lower(name).contains(query))
    })
  })
  .unwrap_or([])
}

///|
fn update_endnote_view(
  emit : @rabbita.Emit[Msg],
  action : EndnoteMsg,
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
                emit(BriefAction(Endnote(FileLoaded(generation, raw)))),
              )
            },
            ".enw",
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
          fail("No EndNote file selected")
        }
        let sources : Array[BriefInputSource] = @json.from_json(sources)
        if sources.is_empty() {
          return (@rabbita.none, view)
        }
        guard sources.length() == 1 else {
          fail("Import one EndNote bibliography at a time")
        }
        let generation = view.generation + 1
        (
          @http.post(product_api_url("/api/v1/briefs/endnote/intake"))
          .with_json({ "source": sources[0].to_json(), "author_filter": "" })
          .expect_json(
            emit.map(reply => BriefAction(Endnote(Imported(generation, reply)))),
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
        let intake : EndnoteIntake = @json.from_json(payload)
        (
          @rabbita.none,
          {
            ..view,
            pending: false,
            endnote: { intake: Some(intake), author_filter: "", selected: [], },
            error: None,
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
    Filter(author_filter) =>
      (@rabbita.none, { ..view, endnote: { ..view.endnote, author_filter, }, })
    Toggle(number) => {
      let selected = if view.endnote.selected.contains(number) {
        view.endnote.selected.filter(item => item != number)
      } else {
        view.endnote.selected + [number]
      }
      (@rabbita.none, { ..view, endnote: { ..view.endnote, selected, }, })
    }
    AddSelected => {
      guard view.endnote.intake is Some(intake) &&
        !view.endnote.selected.is_empty() else {
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
              "EndNote selection uses two source slots: the original file and the selected card metadata",
            ),
          },
        )
      }
      let generation = view.generation + 1
      (
        @http.post(product_api_url("/api/v1/briefs/endnote/select"))
        .with_json({
          "source": intake.source.to_json(),
          "record_numbers": view.endnote.selected.to_json(),
        })
        .expect_json(
          emit.map(reply => BriefAction(Endnote(Selected(generation, reply)))),
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
            endnote: empty_endnote_view(),
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
  }
}
