///|
#warnings("-alert_unstable")
fn main {
  let (emit, cell) = @rabbita.cell_with_emit(
    model=initial_model(),
    update~,
    view~,
  )
  let app = @rabbita.new(cell)
  app.with_init(load_workspace_snapshot(emit))
  app.mount("app")
}
