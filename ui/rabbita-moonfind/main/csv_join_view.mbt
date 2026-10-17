///|
fn csv_join_key_select(
  emit : @rabbita.Emit[Msg],
  intake : CsvIntake?,
  key : Int,
  left : Bool,
  pending : Bool,
) -> @rabbita.Html {
  field_label(
    if left {
      "Left key column (exact text)"
    } else {
      "Right key column (unique nonempty text)"
    },
    select(
      disabled=pending,
      on_change=emit.map(value => {
        let key = @string.parse_int(value) catch { _ => 0 }
        BriefAction(CsvJoin(if left { LeftKey(key) } else { RightKey(key) }))
      }),
      [option(value="0", selected=key == 0, "Choose a key column")] +
      intake
      .map(table => {
        table.columns.mapi((index, column) => {
          option(
            value=(index + 1).to_string(),
            selected=key == index + 1,
            "\{index + 1}: " + column,
          )
        })
      })
      .unwrap_or([]),
    ),
  )
}

///|
fn csv_join_panel(emit : @rabbita.Emit[Msg], view : BriefView) -> @rabbita.Html {
  let state = view.csv_join
  details([
    summary("Join two local evidence tables"),
    p(
      "Import a CSV, pin it as the left table, then import another CSV and pin it as the right table. Each pin retains the complete parsed snapshot, including rows hidden by search. Choose both key columns explicitly.",
    ),
    div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
      action_button(
        "Pin current CSV as left",
        emit(BriefAction(CsvJoin(PinLeft))),
      ),
      action_button(
        "Pin current CSV as right",
        emit(BriefAction(CsvJoin(PinRight))),
      ),
      action_button("Clear join inputs", emit(BriefAction(CsvJoin(Clear)))),
    ]),
    p(
      state.left
      .map(table => {
        "Left: " +
        table.source.name +
        " · \{table.total_count} rows · captured " +
        table.source.captured_at
      })
      .unwrap_or("Left: no pinned table"),
    ),
    p(
      state.right
      .map(table => {
        "Right: " +
        table.source.name +
        " · \{table.total_count} rows · captured " +
        table.source.captured_at
      })
      .unwrap_or("Right: no pinned table"),
    ),
    csv_join_key_select(
      emit,
      state.left,
      state.left_key,
      true,
      view.pending && state.pending_output is None,
    ),
    csv_join_key_select(
      emit,
      state.right,
      state.right_key,
      false,
      view.pending && state.pending_output is None,
    ),
    p(
      "Right fields to append (in original column order). The join key need not be appended; original right source retains every field.",
    ),
    div(
      style=["display:flex", "gap:8px", "flex-wrap:wrap"],
      state.right
      .map(table => {
        table.columns.mapi((index, column) => {
          action_button(
            (if state.right_fields.contains(index + 1) { "✓ " } else { "+ " }) +
            "\{index + 1}: " +
            column,
            emit(
              BriefAction(CsvJoin(ToggleRightField(view.generation, index + 1))),
            ),
          )
        })
      })
      .unwrap_or([]),
    ),
    field_label(
      "Join choice",
      select(
        disabled=view.pending && state.pending_output is None,
        on_change=emit.map(value => BriefAction(CsvJoin(Mode(value)))),
        [
          option(
            value="inner",
            selected=state.mode == "inner",
            "Inner: matched left rows only",
          ),
          option(
            value="left",
            selected=state.mode == "left",
            "Left: every left row, blank right cells when unmatched",
          ),
        ],
      ),
    ),
    p(
      "Keys are exact text: 001 differs from 1, A from a, and spaces are significant. Empty keys never match. Repeated left keys are allowed; duplicate nonempty right keys block the join. No fuzzy or numeric matching, and no many-to-many expansion.",
    ),
    try {
      let preview = csv_join_preview(state)
      div([
        p(
          "\{preview.matched} matched left rows · \{preview.unmatched_left} unmatched left · \{preview.unmatched_right} unmatched right",
        ),
        p(
          "Empty keys: \{preview.empty_left} left, \{preview.empty_right} right. Repeated nonempty key rows beyond the first: \{preview.duplicate_left} left, \{preview.duplicate_right} right.",
        ),
        if !preview.issue.is_empty() {
          p(preview.issue)
        } else {
          div([
            p(
              "\{preview.rows.length()} output rows · \{preview.columns.length()} columns. Left source order is preserved. Original column names are prefixed with side and position to keep headers unique.",
            ),
            details([
              summary("Preview joined CSV and record provenance"),
              p(
                "The first two columns point to logical records in the pinned original files. Record 1 is the header. A blank right record means there was no match. Matched rows can still contain blank right values.",
              ),
              csv_table(
                preview.columns,
                preview.rows,
                record_label="Joined record",
              ),
            ]),
            action_button(
              "Use joined table in CSV explorer",
              emit(BriefAction(CsvJoin(UseJoined))),
              primary=true,
            ),
          ])
        },
      ])
    } catch {
      error => p("\{error}")
    },
    p(
      "The generated CSV goes through the ordinary native CSV intake. Then search, analyze categories or numeric values, choose columns and add selected evidence as usual. No provider is called. At most 512 rows, 32 columns including provenance, and 32 KiB in the generated CSV.",
    ),
    p(
      "Adding joined evidence retains five sources: both complete originals, readable join lineage, the complete joined CSV and the selected-row companion. Unselected private data stays in the originals. Drafts allow eight sources and 128 KiB total. Pinning and previewing alone do not save sources; use Add selected evidence, then Save brief.",
    ),
    p(
      "All cells, including formula-like text, remain exact strings. If downloading the joined CSV, import every column as text in a spreadsheet; quoting does not prevent formulas or automatic conversion. Source metadata is supplied, not verified.",
    ),
    if state.adopted is Some(_) {
      p(
        "The explorer currently contains a joined table. Its original snapshots and lineage will be retained when you add selected evidence. Chained joins are not supported; import another original to start new inputs.",
      )
    } else {
      div("")
    },
  ])
}
