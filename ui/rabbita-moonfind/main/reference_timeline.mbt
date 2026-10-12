///|
struct ReferenceTimeline {
  scope : String
  from_year : String
  through_year : String
  order : String
} derive(Debug, Eq, ToJson)

///|
fn initial_reference_timeline() -> ReferenceTimeline {
  { scope: "all", from_year: "", through_year: "", order: "source", }
}

///|
// Reuse the citation date interpreter, but do not assign a single year to a
// range. The original issued text is never rewritten by this projection.
fn reference_publication_year(issued : String) -> Int? {
  let date = @json.parse(reference_csl_date_json(issued)) catch {
    _ => return None
  }
  match date {
    { "date-parts": Array([Array([Number(year, ..), ..])]), .. } =>
      Some(year.to_int())
    _ => None
  }
}

///|
fn reference_year_bound(value : String) -> Int? {
  let value = value.trim().to_owned()
  guard value.length() == 4 && value.iter().all(c => c >= '0' && c <= '9') else {
    return None
  }
  let year = @string.parse_int(value) catch { _ => return None }
  if year > 0 {
    Some(year)
  } else {
    None
  }
}

///|
fn reference_timeline_problem(timeline : ReferenceTimeline) -> String? {
  if timeline.scope != "years" {
    return None
  }
  let from = reference_year_bound(timeline.from_year)
  let through = reference_year_bound(timeline.through_year)
  if (!timeline.from_year.is_blank() && from is None) ||
    (!timeline.through_year.is_blank() && through is None) {
    return Some(
      "Enter a four-digit year from 0001 to 9999, or leave the bound blank.",
    )
  }
  match (from, through) {
    (Some(a), Some(b)) if a > b =>
      Some("The first publication year must not be later than the last year.")
    _ => None
  }
}

///|
fn reference_timeline_require(view : BriefView) -> Unit raise {
  match reference_timeline_problem(view.reference_timeline) {
    Some(problem) => fail(problem)
    None => ()
  }
}

///|
fn reference_matches(
  view : BriefView,
  catalog : ReferenceCatalog,
) -> Array[ReadingReference] {
  let timeline = view.reference_timeline
  if reference_timeline_problem(timeline) is Some(_) {
    return []
  }
  let from = reference_year_bound(timeline.from_year).unwrap_or(1)
  let through = reference_year_bound(timeline.through_year).unwrap_or(9999)
  let records = reference_search_matches(view, catalog)
    .mapi((index, r) => (index, r, reference_publication_year(r.issued)))
    .filter(item => {
      let (_, _, year) = item
      match timeline.scope {
        "years" => year is Some(y) && y >= from && y <= through
        "unclassified" => year is None
        _ => true
      }
    })
  if timeline.order != "source" {
    records.sort_by((a, b) => {
      let (ai, _, ay) = a
      let (bi, _, by) = b
      let compared = match (ay, by) {
        (None, None) => 0
        (None, Some(_)) => 1
        (Some(_), None) => -1
        (Some(a), Some(b)) =>
          if timeline.order == "newest" {
            b - a
          } else {
            a - b
          }
      }
      if compared == 0 {
        ai - bi
      } else {
        compared
      }
    })
  }
  records.map(item => item.1)
}

///|
enum ReferenceTimelineMsg {
  Scope(String)
  From(String)
  Through(String)
  Order(String)
}

///|
fn update_reference_timeline(
  action : ReferenceTimelineMsg,
  view : BriefView,
) -> (@rabbita.Cmd, BriefView) {
  let timeline = view.reference_timeline
  let next = match action {
    Scope(scope) if scope is ("all" | "years" | "unclassified") =>
      { ..timeline, scope, }
    From(from_year) => { ..timeline, scope: "years", from_year, }
    Through(through_year) => { ..timeline, scope: "years", through_year, }
    Order(order) if order is ("source" | "newest" | "oldest") =>
      { ..timeline, order, }
    _ => timeline
  }
  (@rabbita.none, { ..view, reference_timeline: next, })
}
