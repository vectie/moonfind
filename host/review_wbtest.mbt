///|
async test "immutable review artifacts create once and reject conflicting replay" {
  let workspace = @fs.tmpdir(prefix="moonfind-review-artifact")
  let path = workspace + "/bundle.json"
  ensure_immutable_review_artifact(path, "exact bytes\n", "test bundle")
  ensure_immutable_review_artifact(path, "exact bytes\n", "test bundle")
  assert_eq(@fs.read_file(path).text(), "exact bytes\n")
  let conflict_blocked = try {
    ensure_immutable_review_artifact(path, "different bytes\n", "test bundle")
    false
  } catch {
    _ => true
  }
  assert_true(conflict_blocked)
  assert_eq(@fs.read_file(path).text(), "exact bytes\n")
}
