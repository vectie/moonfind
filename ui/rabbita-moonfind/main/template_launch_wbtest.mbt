///|
test "MoonFind requires complete catalog and source pins for a template preview" {
  assert_true(
    moonfind_template_launch_valid(
      "lunar-habitat-decision-series", "1.0.0", "moonfind.series-templates", "1.0.0",
      "sha256:0efa52d842fb6edaeda28994c15312e461d7c8487803b5340fd0a750c874f853",
      "sha256:3c95e516d9d47301a7312cccd69d2fa257a45d7a58fc949c41474508b1b2fab5",
    ),
  )
  assert_false(
    moonfind_template_launch_valid(
      "lunar-habitat-decision-series", "1.0.0", "moonfind.series-templates", "1.0.0",
      "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "sha256:3c95e516d9d47301a7312cccd69d2fa257a45d7a58fc949c41474508b1b2fab5",
    ),
  )
  assert_false(
    moonfind_template_launch_valid(
      "lunar-habitat-decision-series", "", "", "", "", "",
    ),
  )
}
