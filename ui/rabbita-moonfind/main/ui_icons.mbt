///|
fn research_icon_path(kind : String) -> String {
  match kind {
    "evidence" => "M5 3h14v18H5zM8 7h8M8 11h8M8 15h5"
    "synthesize" => "M4 6h6M4 12h10M4 18h6M17 5v14M14 8l3-3 3 3M14 16l3 3 3-3"
    "challenge" => "M12 3l8 4v5c0 4.5-3 7.3-8 9-5-1.7-8-4.5-8-9V7zM9 12l2 2 4-4"
    "decide" => "M4 4h16v16H4zM8 12l2.5 2.5L16 9"
    "learn" => "M4 19V9M10 19v-5M16 19V5M22 19H2"
    "habitat" => "M3 12l9-8 9 8v8h-6v-5H9v5H3zM8 10h8"
    "series" => "M4 5h6v6H4zM14 5h6v6h-6zM9 17h6M12 11v6"
    "refresh" => "M20 11a8 8 0 1 0-2.3 5.7M20 5v6h-6"
    "shield" => "M12 3l8 4v5c0 4.5-3 7.3-8 9-5-1.7-8-4.5-8-9V7z"
    "inspect" => "M10.5 5H5v14h14v-5.5M9 12l2 2 8-8"
    "check" => "M4 12l5 5L20 6"
    "arrow" => "M5 12h14M14 7l5 5-5 5"
    _ => "M12 4v16M4 12h16"
  }
}

///|
fn research_icon(kind : String, size? : Int = 20) -> @rabbita.Html {
  @html.span(
    class="icon-shell",
    attrs=@html.Attrs::build().aria_hidden("true"),
    @svg.svg(
      class="research-icon",
      width=size,
      height=size,
      view_box="0 0 24 24",
      [
        @svg.path(
          d=research_icon_path(kind),
          fill="none",
          stroke="currentColor",
          stroke_width=2,
          attrs=@svg.Attrs::build()
            .stroke_linecap("round")
            .stroke_linejoin("round"),
        ),
      ],
    ),
  )
}
