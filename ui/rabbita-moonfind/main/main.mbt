///|
#warnings("-alert_unstable")
fn main {
  let model = initial_model()
  let (emit, cell) = @rabbita.cell_with_emit(
    model~,
    update~,
    view~,
  )
  let app = @rabbita.new(cell)
  app.with_init(
    @rabbita.batch([
      load_workspace_snapshot(emit),
      load_moonflow_receiver(
        emit,
        model.moonflow_run_id,
        model.moonflow_handoff_token,
      ),
    ]),
  )
  app.mount("app")
}
