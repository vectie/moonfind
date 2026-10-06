///|
test "authenticated relay and route reads require trusted host origin" {
  assert_true(
    trusted_request_origin("127.0.0.1:4313", "http://127.0.0.1:4313", 4313),
  )
  assert_true(trusted_request_origin("localhost:4313", "", 4313))
  assert_false(
    trusted_request_origin(
      "rebinding.invalid:4313", "http://rebinding.invalid:4313", 4313,
    ),
  )
  assert_false(
    trusted_request_origin("127.0.0.1:4313", "https://untrusted.invalid", 4313),
  )
  assert_false(trusted_request_origin("localhost:4314", "", 4313))
}
