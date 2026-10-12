///|
struct RisReference {
  record_number : Int
  reference_type : String
  title : String
  authors : Array[String]
  year : String
  doi : String
  url : String
  abstract_text : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct RisIntake {
  source : BriefInputSource
  references : Array[RisReference]
  total_count : Int
} derive(Debug, FromJson)

///|
struct RisSelection {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[RisReference]
} derive(Debug, FromJson)

///|
struct RisView {
  intake : RisIntake?
  author_filter : String
  selected : Array[Int]
}

///|
enum RisMsg {
  Choose
  FileLoaded(Int, String)
  Imported(Int, Result[Json, Error])
  Filter(String)
  Toggle(Int)
  AddSelected
  Selected(Int, Result[Json, Error])
}

///|
fn empty_ris_view() -> RisView {
  { intake: None, author_filter: "", selected: [], }
}

///|
extern "js" fn ris_lower(value : String) -> String =
  #|value => Array.from(value, ch => ch.toLowerCase()).join('')

///|
fn ris_filtered(view : RisView) -> Array[RisReference] {
  let query = ris_lower(view.author_filter.trim().to_owned())
  view.intake
  .map(intake => {
    intake.references.filter(reference => {
      query.is_empty() ||
      reference.authors.any(name => ris_lower(name).contains(query))
    })
  })
  .unwrap_or([])
}

///|
fn update_ris_view(
  emit : @rabbita.Emit[Msg],
  action : RisMsg,
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
              scheduler.add(emit(BriefAction(Ris(FileLoaded(generation, raw)))))
            },
            ".ris",
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
          fail("No RIS file selected")
        }
        let sources : Array[BriefInputSource] = @json.from_json(sources)
        if sources.is_empty() {
          return (@rabbita.none, view)
        }
        guard sources.length() == 1 else {
          fail("Import one RIS bibliography at a time")
        }
        let generation = view.generation + 1
        (
          @http.post(product_api_url("/api/v1/briefs/ris/intake"))
          .with_json({ "source": sources[0].to_json(), "author_filter": "" })
          .expect_json(
            emit.map(reply => BriefAction(Ris(Imported(generation, reply)))),
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
        let intake : RisIntake = @json.from_json(payload)
        (
          @rabbita.none,
          {
            ..view,
            pending: false,
            ris: { intake: Some(intake), author_filter: "", selected: [], },
            error: None,
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
    Filter(author_filter) =>
      (@rabbita.none, { ..view, ris: { ..view.ris, author_filter, }, })
    Toggle(number) => {
      let selected = if view.ris.selected.contains(number) {
        view.ris.selected.filter(item => item != number)
      } else {
        view.ris.selected + [number]
      }
      (@rabbita.none, { ..view, ris: { ..view.ris, selected, }, })
    }
    AddSelected => {
      guard view.ris.intake is Some(intake) && !view.ris.selected.is_empty() else {
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
              "RIS selection uses two source slots: the original file and the selected card metadata",
            ),
          },
        )
      }
      let generation = view.generation + 1
      (
        @http.post(product_api_url("/api/v1/briefs/ris/select"))
        .with_json({
          "source": intake.source.to_json(),
          "record_numbers": view.ris.selected.to_json(),
        })
        .expect_json(
          emit.map(reply => BriefAction(Ris(Selected(generation, reply)))),
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
            ris: empty_ris_view(),
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
  }
}
