///|
#warnings("-alert_unstable")
fn main {
  let model = initial_model()
  let (emit, cell) = @rabbita.cell_with_emit(model~, update~, view~)
  let app = @rabbita.new(cell)
  app.with_init(
    if browser_brief_mode() {
      brief_catalog_command(emit, model.brief.generation)
    } else {
      @rabbita.batch([
        load_research_jobs(emit),
        brief_catalog_command(emit, model.brief.generation),
        load_workspace_snapshot(emit, model.workspace_generation),
        load_series_catalog(emit),
        load_moonflow_receiver(
          emit,
          model.moonflow_run_id,
          model.moonflow_handoff_token,
        ),
      ])
    },
  )
  app.mount("app")
}
