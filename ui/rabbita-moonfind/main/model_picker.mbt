///|
fn model_picker(emit : @rabbita.Emit[Msg], model : Model) -> @rabbita.Html {
  let catalog = current_model_catalog(model)
  let choices = catalog.map(catalog_choices).unwrap_or([])
  let configured = catalog.bind(verified_default)
  let current = model.model_name.trim().to_owned()
  let options = [
    option(
      value="",
      disabled=true,
      selected=!choices.contains(current),
      if current.is_empty() {
        "Choose a model"
      } else {
        "Current selection: " + current + " (not in this catalog)"
      },
    ),
  ]
  for selector in choices {
    options.push(
      option(
        value=selector,
        selected=selector == current,
        selector.strip_prefix("moongate/").unwrap_or(selector[:]).to_owned() +
        (if configured == Some(selector) {
          " · configured default"
        } else {
          ""
        }),
      ),
    )
  }
  div(style=["display:grid", "gap:10px"], [
    field_label(
      "Research model",
      select(
        id="research-model-picker",
        disabled=choices.is_empty(),
        on_change=emit.map(value => {
          SelectCatalogModel(model.route_generation, value)
        }),
        style=[
          "width:100%", "min-height:44px", "background:#07101f", "color:#edf5ff",
          "border:1px solid #314563", "border-radius:10px", "padding:10px 12px",
          "font:inherit",
        ],
        options,
      ),
    ),
    div(style=["display:flex", "gap:8px", "flex-wrap:wrap"], [
      button(
        disabled=configured is None,
        on_click=emit(UseConfiguredDefault(model.route_generation)),
        style=["min-height:44px", "padding:10px 14px"],
        "Use configured default",
      ),
      button(
        disabled=model.route_loading ||
          !model.gateway_published ||
          model.workspace is None ||
          model.book_dir != model.trusted_book_dir,
        on_click=emit(RefreshModelRoutes),
        style=["min-height:44px", "padding:10px 14px"],
        if model.route_loading {
          "Refreshing models…"
        } else {
          "Refresh models"
        },
      ),
    ]),
    small(
      style=["color:#aabbd1", "line-height:1.5"],
      model_picker_status(model),
    ),
    if !current.is_empty() {
      small(
        style=["color:#aabbd1", "overflow-wrap:anywhere"],
        "Selected route: " + current,
      )
    } else {
      @html.nothing
    },
    details([
      summary(
        style=["cursor:pointer", "color:#aabbd1"],
        "Advanced: enter an exact model route",
      ),
      field_label(
        "MoonClaw model route",
        text_field(
          model.model_name,
          "Enter a route from your configuration",
          emit.map(value => SetModelName(value)),
        ),
      ),
      small(
        style=["color:#aabbd1"],
        "Manual entries are preserved. A native route still needs to appear in this workspace's catalog before execution.",
      ),
    ]),
  ])
}

///|
fn model_picker_status(model : Model) -> String {
  if !model.gateway_published {
    return "No reachable MoonClaw gateway was published. Restore the gateway connection and refresh the workspace. Your current selection is kept."
  }
  if model.book_dir != model.trusted_book_dir {
    return "Restore the host-bound Book folder to discover its models. No other workspace default is used."
  }
  if model.route_loading {
    return "Checking this workspace's MoonGate catalog. Choosing or refreshing a model does not start research."
  }
  if model.route_error is Some(error) {
    return error
  }
  match current_model_catalog(model) {
    Some(route) if !catalog_choices(route).is_empty() => {
      let status = if verified_default(route) is Some(_) {
        "The configured default is in the reachable MoonGate catalog."
      } else {
        "Choose a model from the reachable MoonGate catalog; no verified default is available."
      }
      let selected_issue = if model.model_name.is_blank() {
        None
      } else {
        model_route_issue(model, model.book_dir)
      }
      status +
      " Provider execution has not been tested. Selecting a model does not start research." +
      selected_issue.map(issue => " " + issue).unwrap_or("")
    }
    _ =>
      model.native_route
      .map(route => route.blocker)
      .filter(value => !value.is_blank())
      .unwrap_or(
        "Model availability has not been verified. Refresh models to check the configured routes.",
      )
  }
}
