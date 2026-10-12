///|
struct CsvCategory {
  value : String
  record_numbers : Array[Int]
} derive(Debug, Eq, ToJson)

///|
fn csv_categories(view : CsvView) -> Array[CsvCategory] {
  guard view.intake is Some(intake) &&
    view.category_column > 0 &&
    view.category_column <= intake.columns.length() else {
    return []
  }
  let rows = if view.category_filtered {
    csv_filtered(view)
  } else {
    intake.rows
  }
  let groups : Array[CsvCategory] = []
  let indexes : Map[String, Int] = {}
  for row in rows {
    let value = row.values[view.category_column - 1]
    match indexes.get(value) {
      Some(index) => groups[index].record_numbers.push(row.record_number)
      None => {
        indexes[value] = groups.length()
        groups.push({ value, record_numbers: [row.record_number], })
      }
    }
  }
  groups.sort_by((a, b) => {
    let counts = b.record_numbers.length().compare(a.record_numbers.length())
    if counts == 0 {
      a.record_numbers[0].compare(b.record_numbers[0])
    } else {
      counts
    }
  })
  groups
}

///|
fn csv_categories_export(view : CsvView) -> String raise {
  guard view.intake is Some(intake) &&
    view.category_column > 0 &&
    view.category_column <= intake.columns.length() else {
    fail("Import a CSV and choose an existing column first.")
  }
  let groups = csv_categories(view)
  (
    {
      "contract_id": "moonfind.csv-category-counts.v1",
      "source": intake.source.to_json(),
      "source_identity": "Exact imported bytes are included as content_hex; metadata is user supplied. Keep this file private: it includes the full original CSV, even in matching-row scope.",
      "source_data_rows": intake.total_count,
      "column_number": view.category_column,
      "column_name": intake.columns[view.category_column - 1],
      "scope": if view.category_filtered {
        "matching_rows"
      } else {
        "all_rows"
      },
      "active_search": {
        "query": view.query,
        "column_number": view.column_number,
        "applied": view.category_filtered,
      },
      "counted_rows": groups.fold(init=0, (count, group) => {
        count + group.record_numbers.length()
      }),
      "groups": groups
      .map(group => {
        (
          {
            "value": group.value,
            "count": group.record_numbers.length(),
            "record_numbers": group.record_numbers.to_json(),
          } : Json)
      })
      .to_json(),
      "semantics": "Exact strings; empty cell is an empty-string group. Whitespace, case and Unicode normalization differences remain distinct. Descending count; ties by first source record. Record 1 is the header; multiline cells occupy one record. Search uses the existing trimmed, case-insensitive literal substring filter.",
      "boundary": "Session-only intake summary, not a retained revision, verified evidence, redaction, or representative sample. No authenticity, statistical significance or research completion claim.",
    } : Json).stringify(indent=2)
}

///|
extern "js" fn csv_categories_download(content : String) -> String =
  #|content => {
  #| let url;
  #| try {
  #|   url=URL.createObjectURL(new Blob([content],{type:'application/json;charset=utf-8'}));
  #|   const link=document.createElement('a'); link.href=url; link.download='moonfind-csv-category-counts.json';
  #|   document.body.appendChild(link); link.click(); link.remove(); return '';
  #| } catch (_) { return 'Category summary download failed; intake remains available. Try again.'; }
  #| finally { if(url) setTimeout(() => URL.revokeObjectURL(url),1000); }
  #|}

///|
fn csv_categories_panel(
  emit : @rabbita.Emit[Msg],
  view : BriefView,
) -> @rabbita.Html {
  guard view.csv.intake is Some(intake) else { return div("") }
  let groups = csv_categories(view.csv)
  let counted = groups.fold(init=0, (n, group) => {
    n + group.record_numbers.length()
  })
  details(open=true, [
    summary("Category counts and source-row drill-down"),
    p(
      "Exact cell strings, including blanks. Case, spaces and Unicode variants remain distinct. Count descending; ties by first source record. Counts describe this imported table only.",
    ),
    field_label(
      "Count values in column",
      select(
        on_change=emit.map(value => {
          BriefAction(
            Csv(CategoryColumn(@string.parse_int(value) catch { _ => 0 })),
          )
        }),
        intake.columns.mapi((i, name) => {
          option(
            value=(i + 1).to_string(),
            selected=view.csv.category_column == i + 1,
            name,
          )
        }),
      ),
    ),
    field_label(
      "Count scope",
      select(
        on_change=emit.map(value => {
          BriefAction(Csv(CategoryScope(value == "matching")))
        }),
        [
          option(
            value="all",
            selected=!view.csv.category_filtered,
            "All imported rows",
          ),
          option(
            value="matching",
            selected=view.csv.category_filtered,
            "Current matching rows",
          ),
        ],
      ),
    ),
    p(
      "\{groups.length()} groups across \{counted} rows. Selecting a group REPLACES the row selection with its source records; it does not change search or output columns. Selected records remain selected when the filter changes.",
    ),
    div(
      groups.map(group => {
        div(style=["white-space:pre-wrap"], [
          action_button(
            (if group.value.is_empty() {
              "(empty cell)"
            } else {
              group.value.to_json().stringify()
            }) +
            " · \{group.record_numbers.length()} rows · Select group",
            emit(BriefAction(Csv(SelectCategory(group.value)))),
          ),
          p(
            "Source records: " +
            group.record_numbers.map(n => n.to_string()).join(", "),
          ),
        ])
      }),
    ),
    p(
      "Download includes the full original CSV bytes and source metadata, plus counts and record membership. This unsaved intake is not a retained revision or verified evidence.",
    ),
    details(open=true, [
      summary("Selected source rows, including rows hidden by search"),
      csv_table(
        intake.columns,
        intake.rows.filter(row => view.csv.selected.contains(row.record_number)),
      ),
    ]),
    action_button(
      "Download category summary JSON",
      emit(BriefAction(Csv(DownloadCategories))),
    ),
  ])
}
