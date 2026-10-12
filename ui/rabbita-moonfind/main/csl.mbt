///|
struct CslReference {
  record_number : Int
  item_id : String
  item_id_kind : String
  citation_key : String
  reference_type : String
  title : String
  authors : Array[String]
  editors : Array[String]
  year : String
  issued : String
  venue : String
  keywords : String
  doi : String
  url : String
  abstract_text : String
  availability : String
} derive(Debug, Eq, ToJson, FromJson)

///|
struct CslIntake {
  source : BriefInputSource
  references : Array[CslReference]
  total_count : Int
} derive(Debug, FromJson)

///|
struct CslSelection {
  contract_id : String
  source_name : String
  source_digest : String
  references : Array[CslReference]
} derive(Debug, FromJson)

///|
struct CslView {
  intake : CslIntake?
  query : String
  selected : Array[Int]
}

///|
enum CslMsg {
  Choose
  FileLoaded(Int, String)
  Imported(Int, Result[Json, Error])
  Filter(String)
  Toggle(Int)
  AddSelected
  Selected(Int, Result[Json, Error])
}

///|
fn empty_csl_view() -> CslView {
  { intake: None, query: "", selected: [], }
}

///|
extern "js" fn csl_lower(value : String) -> String =
  #|value => Array.from(value, ch => ch.toLowerCase()).join('')

///|
fn csl_filtered(view : CslView) -> Array[CslReference] {
  let query = csl_lower(view.query.trim().to_owned())
  view.intake
  .map(intake => {
    intake.references.filter(reference => {
      query.is_empty() ||
      csl_lower(
        [
          reference.item_id,
          reference.citation_key,
          reference.title,
          reference.authors.join("; "),
          reference.editors.join("; "),
          reference.year,
          reference.issued,
          reference.venue,
          reference.keywords,
          reference.doi,
        ].join(" "),
      ).contains(query)
    })
  })
  .unwrap_or([])
}

///|
fn update_csl_view(
  emit : @rabbita.Emit[Msg],
  action : CslMsg,
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
              scheduler.add(emit(BriefAction(Csl(FileLoaded(generation, raw)))))
            },
            ".json",
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
          fail("No CSL JSON file selected")
        }
        let sources : Array[BriefInputSource] = @json.from_json(sources)
        if sources.is_empty() {
          return (@rabbita.none, view)
        }
        guard sources.length() == 1 else {
          fail("Import one CSL JSON bibliography at a time")
        }
        let generation = view.generation + 1
        (
          @http.post(product_api_url("/api/v1/briefs/csl/intake"))
          .with_json({ "source": sources[0].to_json(), "query": "" })
          .expect_json(
            emit.map(reply => BriefAction(Csl(Imported(generation, reply)))),
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
        let intake : CslIntake = @json.from_json(payload)
        (
          @rabbita.none,
          {
            ..view,
            pending: false,
            csl: { intake: Some(intake), query: "", selected: [], },
            error: None,
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
    Filter(query) => (@rabbita.none, { ..view, csl: { ..view.csl, query, }, })
    Toggle(number) => {
      let selected = if view.csl.selected.contains(number) {
        view.csl.selected.filter(item => item != number)
      } else {
        view.csl.selected + [number]
      }
      (@rabbita.none, { ..view, csl: { ..view.csl, selected, }, })
    }
    AddSelected => {
      guard view.csl.intake is Some(intake) && !view.csl.selected.is_empty() else {
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
              "CSL JSON selection uses two source slots: the original file and the selected card metadata",
            ),
          },
        )
      }
      let generation = view.generation + 1
      (
        @http.post(product_api_url("/api/v1/briefs/csl/select"))
        .with_json({
          "source": intake.source.to_json(),
          "record_numbers": view.csl.selected.to_json(),
        })
        .expect_json(
          emit.map(reply => BriefAction(Csl(Selected(generation, reply)))),
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
            csl: empty_csl_view(),
          },
        )
      } catch {
        error =>
          (@rabbita.none, { ..view, pending: false, error: Some("\{error}"), })
      }
  }
}
