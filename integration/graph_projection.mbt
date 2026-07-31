///|
fn graph_catalog_operation(
  catalog : CapabilityCatalogV1,
  operation_ref : String,
) -> CapabilityCatalogOperationV1? {
  let matches = catalog.operations.filter(operation => {
    operation.operation_ref == operation_ref
  })
  match matches {
    [operation] => Some(operation)
    _ => None
  }
}

///|
fn graph_suggestions(
  catalog : CapabilityCatalogV1,
  product_id : String,
) -> Array[String] {
  catalog.operations
  .filter(operation => operation.product_id == product_id)
  .map(operation => operation.operation_ref)
}

///|
fn graph_gap(
  stage_id : String,
  code : String,
  detail : String,
  suggestions : Array[String],
) -> CapabilityGraphGapV1 {
  { stage_id, code, detail, suggestions }
}

///|
fn graph_claim_rank(claim : String) -> Int? {
  match claim {
    "observation" => Some(0)
    "research-evidence" => Some(1)
    "execution-result" => Some(2)
    "accepted-knowledge" => Some(3)
    "digital-artifact" => Some(4)
    "simulation-evidence" => Some(5)
    "scenario-qualified" => Some(6)
    "calibrated-digital-twin" => Some(7)
    "hardware-in-loop-qualified" => Some(8)
    "engineering-unit-qualified" => Some(9)
    "physical-readiness" => Some(10)
    "physical-effect-claim" => Some(11)
    _ => None
  }
}

///|
fn graph_item(stage : DesiredCapabilityStageV2) -> Json raise {
  guard stage.desired_operation_ref is Some(operation) &&
    stage.input_schema_ref is Some(input_schema) &&
    stage.output_schema_ref is Some(output_schema) else {
    fail("an importable graph item must be fully bound")
  }
  {
    "work_item_id": stage.stage_id,
    "declaration_id": stage.declaration_id,
    "product_id": stage.product_id,
    "requested_authority": stage.requested_authority,
    "acceptance_criteria": stage.acceptance_criteria,
    "operation": operation,
    "input_contracts": [input_schema],
    "output_contracts": [output_schema],
    "required_claim": stage.required_claim,
    "input_artifacts": stage.input_artifacts,
    "timeout_ms": stage.timeout_ms,
    "depends_on": stage.depends_on,
    "execution_role": stage.execution_role,
    "execution_config": stage.execution_config,
  }
}

///|
/// Resolve desired product stages only from a compiled MoonFlow catalog.
/// Missing products and tools remain reviewable gaps; no partial work graph is
/// ever emitted.
pub fn project_desired_graph(
  desired : DesiredCapabilityGraphV2,
  catalog : CapabilityCatalogV1,
  evaluated_at : String,
) -> CapabilityGraphProjectionV1 raise {
  guard desired.contract_id == "moonfind.desired-capability-graph.v2" &&
    catalog.contract_id == "moonflow.capability-catalog.v1" &&
    canonical_timestamp(evaluated_at) else {
    fail("unsupported desired graph or capability catalog contract")
  }
  let bindings : Array[CapabilityStageBindingV1] = []
  let gaps : Array[CapabilityGraphGapV1] = []
  let stage_ids : Array[String] = []
  for stage in desired.stages {
    if stage.stage_id.is_blank() || stage_ids.contains(stage.stage_id) {
      gaps.push(
        graph_gap(
          stage.stage_id,
          "stage-identity-invalid",
          "stage IDs must be nonblank and unique",
          [],
        ),
      )
      continue
    }
    stage_ids.push(stage.stage_id)
    let suggestions = graph_suggestions(catalog, stage.product_id)
    guard stage.desired_operation_ref is Some(operation_ref) else {
      gaps.push(
        graph_gap(
          stage.stage_id,
          "operation-unpublished",
          "desired tool `\{stage.desired_tool_hint}` has no published canonical operation",
          suggestions,
        ),
      )
      continue
    }
    guard graph_catalog_operation(catalog, operation_ref) is Some(operation) else {
      gaps.push(
        graph_gap(
          stage.stage_id,
          "operation-unavailable",
          "canonical operation is absent from the healthy catalog: \{operation_ref}",
          suggestions,
        ),
      )
      continue
    }
    let stage_issue_count = gaps.length()
    if operation.product_id != stage.product_id {
      gaps.push(
        graph_gap(
          stage.stage_id,
          "operation-owner-mismatch",
          "operation belongs to \{operation.product_id}, not \{stage.product_id}",
          suggestions,
        ),
      )
    }
    if operation.health_checked_at > evaluated_at ||
      operation.health_valid_until < evaluated_at {
      gaps.push(
        graph_gap(
          stage.stage_id,
          "operation-health-expired",
          "adapter health does not cover \{evaluated_at}",
          [],
        ),
      )
    }
    if operation.authority != stage.requested_authority {
      gaps.push(
        graph_gap(
          stage.stage_id,
          "authority-mismatch",
          "manifest authority is \{operation.authority}, not \{stage.requested_authority}",
          [operation.authority],
        ),
      )
    }
    if stage.input_schema_ref != Some(operation.input_schema_ref) {
      gaps.push(
        graph_gap(
          stage.stage_id,
          "input-schema-mismatch",
          "stage must bind \{operation.input_schema_ref}",
          [operation.input_schema_ref],
        ),
      )
    }
    if stage.output_schema_ref != Some(operation.output_schema_ref) {
      gaps.push(
        graph_gap(
          stage.stage_id,
          "output-schema-mismatch",
          "stage must bind \{operation.output_schema_ref}",
          [operation.output_schema_ref],
        ),
      )
    }
    match
      (
        graph_claim_rank(stage.required_claim),
        graph_claim_rank(operation.claim_ceiling),
      ) {
      (Some(required), Some(ceiling)) =>
        if required > ceiling {
          gaps.push(
            graph_gap(
              stage.stage_id,
              "claim-ceiling-exceeded",
              "required claim \{stage.required_claim} exceeds adapter ceiling \{operation.claim_ceiling}",
              [operation.claim_ceiling],
            ),
          )
        }
      (None, _) =>
        gaps.push(
          graph_gap(
            stage.stage_id,
            "required-claim-unsupported",
            "required_claim is not a canonical MoonSuite claim class",
            [],
          ),
        )
      (_, None) =>
        gaps.push(
          graph_gap(
            stage.stage_id,
            "claim-ceiling-unsupported",
            "catalog operation claim ceiling is not canonical",
            [],
          ),
        )
    }
    if gaps.length() == stage_issue_count {
      bindings.push({
        stage_id: stage.stage_id,
        operation_ref,
        adapter_id: operation.adapter_id,
        input_schema_ref: operation.input_schema_ref,
        output_schema_ref: operation.output_schema_ref,
        authority: operation.authority,
        claim_ceiling: operation.claim_ceiling,
        review_required: operation.review_required,
      })
    }
  }
  for stage in desired.stages {
    for dependency in stage.depends_on {
      if !stage_ids.contains(dependency) {
        gaps.push(
          graph_gap(
            stage.stage_id,
            "dependency-unknown",
            "dependency stage is not declared: \{dependency}",
            [],
          ),
        )
      }
    }
  }
  let fully_conformant = gaps.is_empty() &&
    bindings.length() == desired.stages.length()
  let importable_graph = if fully_conformant {
    let graph : Json = {
      "contract_id": "moonsuite.work-model.v1",
      "graph_id": desired.graph_id,
      "book_id": desired.book_id,
      "declaration_revision": desired.declaration_revision,
      "source_digest": desired.source_digest,
      "recorded_at": evaluated_at,
      "items": Json::array(desired.stages.map(graph_item)),
    }
    Some(graph)
  } else {
    None
  }
  {
    contract_id: "moonfind.capability-graph-projection.v1",
    graph_id: desired.graph_id,
    catalog_id: catalog.catalog_id,
    evaluated_at,
    fully_conformant,
    bindings,
    gaps,
    importable_graph,
  }
}

///|
/// Fail-closed import handoff. MoonFlow receives no graph if any desired stage
/// is absent, unhealthy, version-drifted or schema-drifted.
pub fn require_importable_graph(
  projection : CapabilityGraphProjectionV1,
) -> Json raise {
  guard projection.fully_conformant &&
    projection.importable_graph is Some(graph) else {
    let reasons = projection.gaps.map(gap => "\{gap.stage_id}:\{gap.code}")
    fail("capability graph is not importable: " + reasons.join(", "))
  }
  graph
}

///|
/// Bind a desired graph template to a concrete MoonBook without knowing or
/// replacing any historical graph literal. The caller computes the digest
/// from the complete template identity and target book.
pub fn bind_desired_graph_to_book(
  template : DesiredCapabilityGraphV2,
  book_id : String,
  source_digest : String,
) -> DesiredCapabilityGraphV2 raise {
  guard template.contract_id == "moonfind.desired-capability-graph.v2" &&
    !template.graph_id.is_blank() &&
    !book_id.is_blank() &&
    source_digest.has_prefix("sha256:") &&
    source_digest.length() == 71 else {
    fail(
      "desired graph binding requires a v2 template, book ID, and sha256 digest",
    )
  }
  {
    ..template,
    graph_id: template.graph_id + "--book-" + book_id,
    book_id,
    source_digest,
  }
}
