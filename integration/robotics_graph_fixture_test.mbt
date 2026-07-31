///|
/// Synthetic desired stage used only to verify the full cross-product graph.
/// The checked-in JSON remains the operator-facing source of intent.
fn robotics_stage(
  stage_id : String,
  product_id : String,
  operation_ref : String,
  authority : String,
  input_schema : String,
  output_schema : String,
  claim : String,
  depends_on : Array[String],
) -> @integration.DesiredCapabilityStageV2 {
  let execution_role = match stage_id {
    "understand-needs" | "requirements-agent-check" => Some("wiki")
    "build-control-software" => Some("mooncode")
    "bookkeeper-close-loop" => Some("bookkeeper")
    _ => None
  }
  let execution_config : Json? = match stage_id {
    "requirements-agent-check" | "build-control-software" =>
      Some({ "model": "gpt-5.6-sol", "runtime": "moonclaw" })
    "bookkeeper-close-loop" =>
      Some({ "three_gap_assessments": 1, "self_approval_forbidden": true })
    _ => None
  }
  {
    stage_id,
    declaration_id: stage_id + "-v3",
    product_id,
    desired_operation_ref: Some(operation_ref),
    desired_tool_hint: operation_ref,
    execution_role,
    execution_config,
    requested_authority: authority,
    input_schema_ref: Some(input_schema),
    output_schema_ref: Some(output_schema),
    required_claim: claim,
    acceptance_criteria: ["fixture stage must bind exactly"],
    input_artifacts: [
      "requests/" +
      stage_id +
      "." +
      input_schema.replace(old=product_id + "/", new="").split("@").collect()[0].to_owned() +
      ".json",
    ],
    timeout_ms: 600000,
    depends_on,
  }
}

///|
fn robotics_pack_version(product_id : String) -> String {
  match product_id {
    "moonclaw" => "0.1.5"
    "moonmold" | "moonrobo" | "mooncast" => "0.2.0"
    _ => "0.1.0"
  }
}

///|
fn robotics_fixture_idempotent(operation_ref : String) -> Bool {
  ![
    "mooncast/animatic.render@0.2.0", "mooncast/asset-factory.generate@0.2.0", "mooncast/production-coordinator.run-pending@0.2.0",
    "mooncast/client-portal.create@0.2.0", "mooncast/client-portal.decide@0.2.0",
  ].contains(operation_ref)
}

///|
fn full_robotics_desired_graph() -> @integration.DesiredCapabilityGraphV2 {
  {
    contract_id: "moonfind.desired-capability-graph.v2",
    graph_id: "moonfind-humanoid-robotics-suite-v3",
    book_id: "moonfind-humanoid-robotics",
    declaration_revision: "desired-v3-exact-capabilities",
    source_digest: "sha256:a1a628f19bf3cf8e1f56344122160a105e512569c3f9f97388c67178304e4c89",
    support_topology: Some({
      "execution_engine": "moonflow",
      "policy_and_catalog": "moongate",
    }),
    intentional_exclusions: Some([
      { "product_id": "moonfish" },
      { "capability": "physical robot command" },
      { "capability": "publication" },
    ]),
    stages: [
      robotics_stage(
        "understand-needs",
        "moonbook",
        "moonbook/wiki.requirements.prepare@0.1.0",
        "workspace-mutation",
        "moonbook/wiki-requirements-prepare@1.0.0",
        "moonbook/wiki-requirements-packet@1.0.0",
        "digital-artifact",
        [],
      ),
      robotics_stage(
        "owner-requirements-review",
        "moonchat",
        "moonchat/conversation.review.record@0.1.0",
        "workspace-mutation",
        "moonchat/conversation-review-bundle@1.0.0",
        "moonchat/conversation-review-record@1.0.0",
        "accepted-knowledge",
        ["understand-needs"],
      ),
      robotics_stage(
        "requirements-agent-check",
        "moonclaw",
        "moonclaw/agent.goal.execute@0.1.5",
        "workspace-mutation",
        "moonclaw/agent-goal-execution-request@1.0.0",
        "moonclaw/agent-goal-execution-receipt@1.0.0",
        "digital-artifact",
        ["owner-requirements-review"],
      ),
      robotics_stage(
        "research-evidence",
        "moonfind",
        "moonfind/research.cross-paper-synthesize@0.1.0",
        "sandbox-execution",
        "moonfind/research-run@1.0.0",
        "moonfind/moontown-research-scenario@1.0.0",
        "research-evidence",
        ["requirements-agent-check"],
      ),
      robotics_stage(
        "challenge-concept",
        "moontown",
        "moontown/civic.communication.synthesize@0.1.0",
        "workspace-mutation",
        "moontown/civic-communication-handoff@1.0.0",
        "moontown/civic-synthesis-result@1.0.0",
        "execution-result",
        ["research-evidence"],
      ),
      robotics_stage(
        "stakeholder-review",
        "moonchat",
        "moonchat/conversation.review.record@0.1.0",
        "workspace-mutation",
        "moonchat/conversation-review-bundle@1.0.0",
        "moonchat/conversation-review-record@1.0.0",
        "accepted-knowledge",
        ["challenge-concept"],
      ),
      robotics_stage(
        "plan-project",
        "moonproj",
        "moonproj/project.plan.prepare@0.1.0",
        "workspace-mutation",
        "moonproj/project-plan-request@1.0.0",
        "moonproj/project-plan-artifact@1.0.0",
        "digital-artifact",
        ["stakeholder-review"],
      ),
      robotics_stage(
        "build-control-software",
        "moonclaw",
        "moonclaw/agent.goal.execute@0.1.5",
        "workspace-mutation",
        "moonclaw/agent-goal-execution-request@1.0.0",
        "moonclaw/agent-goal-execution-receipt@1.0.0",
        "digital-artifact",
        ["plan-project"],
      ),
      robotics_stage(
        "design-physical-assets",
        "moonmold",
        "moonmold/spatial.operation.execute@0.2.0",
        "workspace-mutation",
        "moonmold/spatial-operation-request@1.0.0",
        "moonmold/spatial-operation-receipt@1.0.0",
        "digital-artifact",
        ["plan-project"],
      ),
      robotics_stage(
        "integrate-robot",
        "moonrobo",
        "moonrobo/robot.integrate-digital-model@0.2.0",
        "workspace-mutation",
        "moonrobo/robot-design@1.0.0",
        "moonrobo/digital-model-integration-receipt@1.0.0",
        "digital-artifact",
        ["build-control-software", "design-physical-assets"],
      ),
      robotics_stage(
        "simulate-missions",
        "moonmoon",
        "moonmoon/simulation.robot-mission@0.1.0",
        "sandbox-execution",
        "moonmoon/robot-mission-run-request@1.0.0",
        "moonmoon/mission-simulation-receipt@1.0.0",
        "calibrated-digital-twin",
        ["integrate-robot"],
      ),
      robotics_stage(
        "readiness-inspect",
        "moonrobo",
        "moonrobo/robot.readiness.inspect@0.2.0",
        "observe",
        "moonrobo/robobook-ref@1.0.0",
        "moonrobo/readiness-observation@1.0.0",
        "observation",
        ["simulate-missions"],
      ),
      robotics_stage(
        "visualize-deliverable",
        "moonvis",
        "moonvis/visual.asset-bundle.resolve@0.1.0",
        "workspace-mutation",
        "moonvis/visual-asset-bundle-request@1.0.0",
        "moonvis/visual-asset-bundle-manifest@1.0.0",
        "digital-artifact",
        ["readiness-inspect"],
      ),
      robotics_stage(
        "mooncast-project-create",
        "mooncast",
        "mooncast/project.create@0.2.0",
        "sandbox-execution",
        "mooncast/creative-brief@1.0.0",
        "mooncast/production-project@1.0.0",
        "execution-result",
        ["stakeholder-review", "plan-project", "visualize-deliverable"],
      ),
      robotics_stage(
        "mooncast-brief-revise",
        "mooncast",
        "mooncast/creative.artifact.revise@0.2.0",
        "workspace-mutation",
        "mooncast/creative-revision-request@1.0.0",
        "mooncast/creative-artifact@1.0.0",
        "execution-result",
        ["mooncast-project-create"],
      ),
      robotics_stage(
        "mooncast-brief-decide",
        "mooncast",
        "mooncast/creative.artifact.decide@0.2.0",
        "workspace-mutation",
        "mooncast/creative-decision-request@1.0.0",
        "mooncast/creative-decision@1.0.0",
        "execution-result",
        ["mooncast-brief-revise"],
      ),
      robotics_stage(
        "mooncast-advance-g0",
        "mooncast",
        "mooncast/project.advance@0.2.0",
        "workspace-mutation",
        "mooncast/gate-decision@1.0.0",
        "mooncast/production-project@1.0.0",
        "execution-result",
        ["mooncast-brief-decide"],
      ),
      robotics_stage(
        "mooncast-rights-revise",
        "mooncast",
        "mooncast/creative.artifact.revise@0.2.0",
        "workspace-mutation",
        "mooncast/creative-revision-request@1.0.0",
        "mooncast/creative-artifact@1.0.0",
        "execution-result",
        ["mooncast-advance-g0"],
      ),
      robotics_stage(
        "mooncast-rights-decide",
        "mooncast",
        "mooncast/creative.artifact.decide@0.2.0",
        "workspace-mutation",
        "mooncast/creative-decision-request@1.0.0",
        "mooncast/creative-decision@1.0.0",
        "execution-result",
        ["mooncast-rights-revise"],
      ),
      robotics_stage(
        "mooncast-advance-g1",
        "mooncast",
        "mooncast/project.advance@0.2.0",
        "workspace-mutation",
        "mooncast/gate-decision@1.0.0",
        "mooncast/production-project@1.0.0",
        "execution-result",
        ["mooncast-rights-decide"],
      ),
      robotics_stage(
        "mooncast-bible-revise",
        "mooncast",
        "mooncast/creative.artifact.revise@0.2.0",
        "workspace-mutation",
        "mooncast/creative-revision-request@1.0.0",
        "mooncast/creative-artifact@1.0.0",
        "execution-result",
        ["mooncast-advance-g1"],
      ),
      robotics_stage(
        "mooncast-bible-decide",
        "mooncast",
        "mooncast/creative.artifact.decide@0.2.0",
        "workspace-mutation",
        "mooncast/creative-decision-request@1.0.0",
        "mooncast/creative-decision@1.0.0",
        "execution-result",
        ["mooncast-bible-revise"],
      ),
      robotics_stage(
        "mooncast-script-revise",
        "mooncast",
        "mooncast/creative.artifact.revise@0.2.0",
        "workspace-mutation",
        "mooncast/creative-revision-request@1.0.0",
        "mooncast/creative-artifact@1.0.0",
        "execution-result",
        ["mooncast-bible-decide"],
      ),
      robotics_stage(
        "mooncast-script-decide",
        "mooncast",
        "mooncast/creative.artifact.decide@0.2.0",
        "workspace-mutation",
        "mooncast/creative-decision-request@1.0.0",
        "mooncast/creative-decision@1.0.0",
        "execution-result",
        ["mooncast-script-revise"],
      ),
      robotics_stage(
        "mooncast-advance-g2",
        "mooncast",
        "mooncast/project.advance@0.2.0",
        "workspace-mutation",
        "mooncast/gate-decision@1.0.0",
        "mooncast/production-project@1.0.0",
        "execution-result",
        ["mooncast-script-decide"],
      ),
      robotics_stage(
        "mooncast-storyboard-revise",
        "mooncast",
        "mooncast/creative.artifact.revise@0.2.0",
        "workspace-mutation",
        "mooncast/creative-revision-request@1.0.0",
        "mooncast/creative-artifact@1.0.0",
        "execution-result",
        ["mooncast-advance-g2"],
      ),
      robotics_stage(
        "mooncast-storyboard-decide",
        "mooncast",
        "mooncast/creative.artifact.decide@0.2.0",
        "workspace-mutation",
        "mooncast/creative-decision-request@1.0.0",
        "mooncast/creative-decision@1.0.0",
        "execution-result",
        ["mooncast-storyboard-revise"],
      ),
      robotics_stage(
        "mooncast-animatic-plan",
        "mooncast",
        "mooncast/animatic.plan.record@0.2.0",
        "workspace-mutation",
        "mooncast/animatic-plan@1.0.0",
        "mooncast/animatic-plan@1.0.0",
        "digital-artifact",
        ["mooncast-storyboard-decide"],
      ),
      robotics_stage(
        "mooncast-animatic-render",
        "mooncast",
        "mooncast/animatic.render@0.2.0",
        "sandbox-execution",
        "mooncast/animatic-plan@1.0.0",
        "mooncast/rendered-animatic@1.0.0",
        "digital-artifact",
        ["mooncast-animatic-plan"],
      ),
      robotics_stage(
        "mooncast-animatic-approve",
        "mooncast",
        "mooncast/animatic.approve@0.2.0",
        "workspace-mutation",
        "mooncast/rendered-animatic@1.0.0",
        "mooncast/rendered-animatic-approval@1.0.0",
        "accepted-knowledge",
        ["mooncast-animatic-render"],
      ),
      robotics_stage(
        "mooncast-advance-g3",
        "mooncast",
        "mooncast/project.advance@0.2.0",
        "workspace-mutation",
        "mooncast/gate-decision@1.0.0",
        "mooncast/production-project@1.0.0",
        "execution-result",
        ["mooncast-animatic-approve"],
      ),
      robotics_stage(
        "mooncast-asset-plan",
        "mooncast",
        "mooncast/asset-factory.plan.record@0.2.0",
        "workspace-mutation",
        "mooncast/asset-factory-plan@1.0.0",
        "mooncast/asset-factory-plan@1.0.0",
        "digital-artifact",
        ["mooncast-advance-g3"],
      ),
      robotics_stage(
        "mooncast-asset-generate",
        "mooncast",
        "mooncast/asset-factory.generate@0.2.0",
        "external-effect",
        "mooncast/asset-factory-plan@1.0.0",
        "mooncast/asset-generation-variant@1.0.0",
        "digital-artifact",
        ["mooncast-asset-plan"],
      ),
      robotics_stage(
        "mooncast-asset-review",
        "mooncast",
        "mooncast/asset-factory.review@0.2.0",
        "workspace-mutation",
        "mooncast/asset-qc-finding@1.0.0",
        "mooncast/approved-reusable-asset@1.0.0",
        "accepted-knowledge",
        ["mooncast-asset-generate"],
      ),
      robotics_stage(
        "mooncast-asset-bind-shots",
        "mooncast",
        "mooncast/asset-factory.bind-shots@0.2.0",
        "workspace-mutation",
        "mooncast/approved-reusable-asset@1.0.0",
        "mooncast/shot-asset-binding@1.0.0",
        "execution-result",
        ["mooncast-asset-review"],
      ),
      robotics_stage(
        "mooncast-routing-revise",
        "mooncast",
        "mooncast/model-routing.plan.revise@0.2.0",
        "workspace-mutation",
        "mooncast/model-routing-plan@1.0.0",
        "mooncast/model-routing-plan@1.0.0",
        "execution-result",
        ["mooncast-asset-bind-shots"],
      ),
      robotics_stage(
        "mooncast-routing-producer-decide",
        "mooncast",
        "mooncast/model-routing.plan.decide@0.2.0",
        "workspace-mutation",
        "mooncast/model-routing-plan@1.0.0",
        "mooncast/model-routing-decision@1.0.0",
        "accepted-knowledge",
        ["mooncast-routing-revise"],
      ),
      robotics_stage(
        "mooncast-routing-finance-decide",
        "mooncast",
        "mooncast/model-routing.plan.decide@0.2.0",
        "workspace-mutation",
        "mooncast/model-routing-plan@1.0.0",
        "mooncast/model-routing-decision@1.0.0",
        "accepted-knowledge",
        ["mooncast-routing-revise"],
      ),
      robotics_stage(
        "mooncast-routed-execution-create",
        "mooncast",
        "mooncast/routed-execution.create@0.2.0",
        "workspace-mutation",
        "mooncast/routed-execution-create@1.0.0",
        "mooncast/routed-execution@1.0.0",
        "execution-result",
        ["mooncast-routing-producer-decide", "mooncast-routing-finance-decide"],
      ),
      robotics_stage(
        "mooncast-production-run",
        "mooncast",
        "mooncast/production-coordinator.run-pending@0.2.0",
        "external-effect",
        "mooncast/production-coordinator-run-request@1.0.0",
        "mooncast/production-coordinator-run-result@1.0.0",
        "digital-artifact",
        ["mooncast-routed-execution-create"],
      ),
      robotics_stage(
        "mooncast-production-confirm-qc",
        "mooncast",
        "mooncast/production-coordinator.confirm-qc@0.2.0",
        "workspace-mutation",
        "mooncast/production-coordinator-qc-request@1.0.0",
        "mooncast/production-coordinator-qc-result@1.0.0",
        "accepted-knowledge",
        ["mooncast-production-run"],
      ),
      robotics_stage(
        "mooncast-advance-g4",
        "mooncast",
        "mooncast/project.advance@0.2.0",
        "workspace-mutation",
        "mooncast/gate-decision@1.0.0",
        "mooncast/production-project@1.0.0",
        "execution-result",
        ["mooncast-production-confirm-qc"],
      ),
      robotics_stage(
        "mooncast-editor-import",
        "mooncast",
        "mooncast/editor.production.import@0.2.0",
        "workspace-mutation",
        "mooncast/editor-production-intent@1.0.0",
        "mooncast/editor-production-import@1.0.0",
        "digital-artifact",
        ["mooncast-advance-g4"],
      ),
      robotics_stage(
        "mooncast-editor-narrative-cut",
        "mooncast",
        "mooncast/editor.command.apply@0.2.0",
        "workspace-mutation",
        "mooncast/editor-edit-command@1.0.0",
        "mooncast/editor-project@1.0.0",
        "digital-artifact",
        ["mooncast-editor-import"],
      ),
      robotics_stage(
        "mooncast-editor-compliance-cut",
        "mooncast",
        "mooncast/editor.command.apply@0.2.0",
        "workspace-mutation",
        "mooncast/editor-edit-command@1.0.0",
        "mooncast/editor-project@1.0.0",
        "digital-artifact",
        ["mooncast-editor-narrative-cut"],
      ),
      robotics_stage(
        "mooncast-editor-preview-plan",
        "mooncast",
        "mooncast/editor.preview.plan@0.2.0",
        "sandbox-execution",
        "mooncast/editor-project@1.0.0",
        "mooncast/editor-render-plan@1.0.0",
        "digital-artifact",
        ["mooncast-editor-compliance-cut"],
      ),
      robotics_stage(
        "mooncast-editor-preview-start",
        "mooncast",
        "mooncast/editor.preview.start@0.2.0",
        "sandbox-execution",
        "mooncast/editor-render-plan@1.0.0",
        "mooncast/editor-preview-session@1.0.0",
        "digital-artifact",
        ["mooncast-editor-preview-plan"],
      ),
      robotics_stage(
        "mooncast-editor-export-create",
        "mooncast",
        "mooncast/editor.export.create@0.2.0",
        "sandbox-execution",
        "mooncast/editor-render-plan@1.0.0",
        "mooncast/editor-export-job@1.0.0",
        "digital-artifact",
        ["mooncast-editor-preview-start"],
      ),
      robotics_stage(
        "mooncast-editor-production-export",
        "mooncast",
        "mooncast/editor.production.export@0.2.0",
        "workspace-mutation",
        "mooncast/editor-production-export-request@1.0.0",
        "mooncast/editor-export@1.0.0",
        "digital-artifact",
        ["mooncast-editor-export-create"],
      ),
      robotics_stage(
        "mooncast-editor-master-promote",
        "mooncast",
        "mooncast/editor.master.promote@0.2.0",
        "workspace-mutation",
        "mooncast/editor-master-promotion@1.0.0",
        "mooncast/master-provenance@1.0.0",
        "digital-artifact",
        ["mooncast-editor-production-export"],
      ),
      robotics_stage(
        "mooncast-technical-review",
        "mooncast",
        "mooncast/production.review@0.2.0",
        "workspace-mutation",
        "mooncast/master-provenance@1.0.0",
        "mooncast/review-decision@1.0.0",
        "accepted-knowledge",
        ["mooncast-editor-master-promote"],
      ),
      robotics_stage(
        "mooncast-creative-review",
        "mooncast",
        "mooncast/production.review@0.2.0",
        "workspace-mutation",
        "mooncast/master-provenance@1.0.0",
        "mooncast/review-decision@1.0.0",
        "accepted-knowledge",
        ["mooncast-editor-master-promote"],
      ),
      robotics_stage(
        "mooncast-rights-review",
        "mooncast",
        "mooncast/production.review@0.2.0",
        "workspace-mutation",
        "mooncast/master-provenance@1.0.0",
        "mooncast/review-decision@1.0.0",
        "accepted-knowledge",
        ["mooncast-editor-master-promote"],
      ),
      robotics_stage(
        "mooncast-advance-g5",
        "mooncast",
        "mooncast/project.advance@0.2.0",
        "workspace-mutation",
        "mooncast/gate-decision@1.0.0",
        "mooncast/production-project@1.0.0",
        "execution-result",
        [
          "mooncast-technical-review", "mooncast-creative-review", "mooncast-rights-review",
        ],
      ),
      robotics_stage(
        "mooncast-delivery-prepare",
        "mooncast",
        "mooncast/delivery.prepare@0.2.0",
        "sandbox-execution",
        "mooncast/production-project@1.0.0",
        "mooncast/delivery-package-v2@1.0.0",
        "digital-artifact",
        ["mooncast-advance-g5"],
      ),
      robotics_stage(
        "mooncast-delivery-build-plan",
        "mooncast",
        "mooncast/delivery-build.plan@0.2.0",
        "workspace-mutation",
        "mooncast/delivery-build-request@1.0.0",
        "mooncast/delivery-build@1.0.0",
        "digital-artifact",
        ["mooncast-delivery-prepare"],
      ),
      robotics_stage(
        "mooncast-delivery-build-execute",
        "mooncast",
        "mooncast/delivery-build.execute@0.2.0",
        "sandbox-execution",
        "mooncast/delivery-build-action@1.0.0",
        "mooncast/delivery-build@1.0.0",
        "digital-artifact",
        ["mooncast-delivery-build-plan"],
      ),
      robotics_stage(
        "mooncast-delivery-build-accept",
        "mooncast",
        "mooncast/delivery-build.accept@0.2.0",
        "workspace-mutation",
        "mooncast/delivery-build-acceptance@1.0.0",
        "mooncast/delivery-milestone-acceptance@1.0.0",
        "accepted-knowledge",
        ["mooncast-delivery-build-execute"],
      ),
      robotics_stage(
        "mooncast-client-portal-create",
        "mooncast",
        "mooncast/client-portal.create@0.2.0",
        "workspace-mutation",
        "mooncast/client-portal-create@1.0.0",
        "mooncast/client-portal@1.0.0",
        "execution-result",
        ["mooncast-delivery-build-accept"],
      ),
      robotics_stage(
        "mooncast-client-portal-decide",
        "mooncast",
        "mooncast/client-portal.decide@0.2.0",
        "workspace-mutation",
        "mooncast/client-decision-request@1.0.0",
        "mooncast/client-decision-receipt@1.0.0",
        "accepted-knowledge",
        ["mooncast-client-portal-create"],
      ),
      robotics_stage(
        "mooncast-final-deliverable-evidence",
        "mooncast",
        "mooncast/handoff.final-deliverable.evidence@0.2.0",
        "workspace-mutation",
        "mooncast/final-deliverable-evidence@1.0.0",
        "mooncast/final-deliverable-evidence@1.0.0",
        "execution-result",
        ["mooncast-client-portal-decide"],
      ),
      robotics_stage(
        "final-authority-decision",
        "moonchat",
        "moonchat/conversation.review.record@0.1.0",
        "workspace-mutation",
        "moonchat/conversation-review-bundle@1.0.0",
        "moonchat/conversation-review-record@1.0.0",
        "accepted-knowledge",
        [
          "readiness-inspect", "simulate-missions", "mooncast-final-deliverable-evidence",
        ],
      ),
      robotics_stage(
        "bookkeeper-close-loop",
        "moonbook",
        "moonbook/bookkeeper.outcome.close@0.1.0",
        "workspace-mutation",
        "moonbook/bookkeeper-product-outcome-closure@1.0.0",
        "moonbook/bookkeeper-product-outcome-closure-receipt@1.0.0",
        "digital-artifact",
        ["final-authority-decision", "mooncast-final-deliverable-evidence"],
      ),
    ],
  }
}

///|
fn robotics_catalog(
  desired : @integration.DesiredCapabilityGraphV2,
) -> @integration.CapabilityCatalogV1 raise {
  let operations : Array[@integration.CapabilityCatalogOperationV1] = []
  let products : Array[@integration.CapabilityCatalogProductV1] = []
  for stage in desired.stages {
    guard stage.desired_operation_ref is Some(operation_ref) &&
      stage.input_schema_ref is Some(input_schema_ref) &&
      stage.output_schema_ref is Some(output_schema_ref) else {
      fail("robotics fixture stages must be exact")
    }
    if !operations.any(operation => operation.operation_ref == operation_ref) {
      operations.push({
        operation_ref,
        product_id: stage.product_id,
        pack_id: stage.product_id,
        pack_version: robotics_pack_version(stage.product_id),
        tool_id: stage.desired_tool_hint,
        adapter_id: "fixture-only-" + stage.product_id,
        protocol: "moonflow.adapter.v2",
        authority: stage.requested_authority,
        input_schema_ref,
        output_schema_ref,
        claim_ceiling: stage.required_claim,
        idempotent: robotics_fixture_idempotent(operation_ref),
        review_required: stage.required_claim == "accepted-knowledge",
        supports_cancel: false,
        supports_reconcile: true,
        health_checked_at: "2026-07-31T00:00:00Z",
        health_valid_until: "2026-08-01T00:00:00Z",
        health_evidence_ref: "fixtures/synthetic-health/" +
        stage.stage_id +
        ".json",
        health_evidence_digest: "sha256:" + "a".repeat(64),
      })
    }
    if !products.any(product => product.product_id == stage.product_id) {
      products.push({
        product_id: stage.product_id,
        pack_id: stage.product_id,
        pack_version: robotics_pack_version(stage.product_id),
      })
    }
  }
  {
    contract_id: "moonflow.capability-catalog.v1",
    catalog_id: "fixture-only-humanoid-robotics-exact-v1",
    compiled_at: "2026-07-31T00:00:00Z",
    conformant: true,
    products,
    operations,
    issues: [],
  }
}

///|
test "full exact robotics graph imports only as one conformant graph" {
  let desired = full_robotics_desired_graph()
  let catalog = robotics_catalog(desired)
  assert_eq(desired.stages.length(), 63)
  assert_eq(catalog.operations.length(), 43)
  assert_eq(
    catalog.operations.filter(operation => !operation.idempotent).length(),
    5,
  )
  assert_false(catalog.operations.any(operation => operation.supports_cancel))
  assert_false(desired.stages.any(stage => stage.desired_operation_ref is None))
  assert_false(desired.stages.any(stage => stage.input_artifacts.is_empty()))
  assert_false(desired.stages.any(stage => stage.input_artifacts.length() != 1))
  for stage in desired.stages {
    guard stage.input_schema_ref is Some(schema_ref) else {
      fail("fixture stage must bind an input schema")
    }
    let schema_name = schema_ref
    .replace(old=stage.product_id + "/", new="")
    .split("@")
    .collect()[0].to_owned()
    assert_eq(
      stage.input_artifacts[0],
      "requests/" + stage.stage_id + "." + schema_name + ".json",
    )
  }
  assert_false(desired.stages.any(stage => stage.product_id == "moongate"))
  let projection = @integration.project_desired_graph(
    desired, catalog, "2026-07-31T12:00:00Z",
  )
  assert_true(projection.fully_conformant)
  assert_eq(projection.bindings.length(), 63)
  assert_true(projection.gaps.is_empty())
  assert_true(projection.importable_graph is Some(_))
  let imported = @integration.require_importable_graph(projection)
  guard imported is Object(fields) && fields.get("items") is Some(Array(items)) else {
    fail("projection must emit a complete MoonFlow work-model item array")
  }
  assert_eq(items.length(), 63)
  for item in items {
    guard item is Object(item_fields) &&
      item_fields.get("input_artifacts") is Some(Array(artifacts)) else {
      fail("every projected item must carry its typed request artifact")
    }
    assert_eq(artifacts.length(), 1)
  }
}

///|
test "one missing operation blocks the whole graph without a partial import" {
  let desired = full_robotics_desired_graph()
  let catalog = robotics_catalog(desired)
  let missing = {
    ..catalog,
    operations: catalog.operations.filter(operation => {
      operation.operation_ref !=
      "mooncast/handoff.final-deliverable.evidence@0.2.0"
    }),
  }
  let projection = @integration.project_desired_graph(
    desired, missing, "2026-07-31T12:00:00Z",
  )
  assert_false(projection.fully_conformant)
  assert_true(projection.importable_graph is None)
  assert_true(
    projection.gaps.any(gap => {
      gap.code == "operation-unavailable" &&
      gap.stage_id == "mooncast-final-deliverable-evidence"
    }),
  )
}

///|
test "one expired operation blocks the whole graph without a partial import" {
  let desired = full_robotics_desired_graph()
  let catalog = robotics_catalog(desired)
  let expired = {
    ..catalog,
    operations: catalog.operations.map(operation => {
      if operation.operation_ref == "mooncast/asset-factory.generate@0.2.0" {
        { ..operation, health_valid_until: "2026-07-31T11:59:59Z" }
      } else {
        operation
      }
    }),
  }
  let projection = @integration.project_desired_graph(
    desired, expired, "2026-07-31T12:00:00Z",
  )
  assert_false(projection.fully_conformant)
  assert_true(projection.importable_graph is None)
  assert_true(
    projection.gaps.any(gap => {
      gap.code == "operation-health-expired" &&
      gap.stage_id == "mooncast-asset-generate"
    }),
  )
}

///|
test "publisher binding derives identity from the v2 template" {
  let template = full_robotics_desired_graph()
  let digest = "sha256:" + "d".repeat(64)
  let bound = @integration.bind_desired_graph_to_book(
    template, "client-robotics-book", digest,
  )
  assert_eq(
    bound.graph_id,
    "moonfind-humanoid-robotics-suite-v3--book-client-robotics-book",
  )
  assert_eq(bound.book_id, "client-robotics-book")
  assert_eq(bound.source_digest, digest)
  assert_false(bound.source_digest == template.source_digest)
  assert_false(bound.graph_id.contains("suite-v1"))
  assert_eq(bound.declaration_revision, template.declaration_revision)
  assert_eq(bound.stages, template.stages)
  assert_true(bound.support_topology is Some(_))
  assert_true(bound.intentional_exclusions is Some(_))
}

///|
test "request materialization is complete and fails closed on one missing payload" {
  let desired = full_robotics_desired_graph()
  let entries : Array[@integration.RoboticsRequestMaterializationEntryV1] = []
  let payloads : Array[@integration.RoboticsRequestPayloadV1] = []
  for stage in desired.stages {
    guard stage.input_schema_ref is Some(input_schema_ref) else {
      fail("fixture stage must bind an input schema")
    }
    let artifact_ref = stage.input_artifacts[0]
    let digest = "sha256:" + "e".repeat(64)
    guard @integration.robotics_request_schema_digest(input_schema_ref)
      is Some(schema_digest) else {
      fail("fixture schema must exist in the reviewed template registry")
    }
    let contract = @integration.robotics_request_contract_constant(
      input_schema_ref,
    )
    let payload : Json = match contract {
      Some(("contract", value)) =>
        { "stage_id": stage.stage_id, "contract": value }
      Some(("contract_id", value)) =>
        { "stage_id": stage.stage_id, "contract_id": value }
      _ => { "stage_id": stage.stage_id }
    }
    let constant_top_level_fields : Json = match contract {
      Some(("contract", value)) => { "contract": value }
      Some(("contract_id", value)) => { "contract_id": value }
      _ => Json::empty_object()
    }
    let required_top_level_fields = match contract {
      Some(("contract", _)) => ["stage_id", "contract"]
      Some(("contract_id", _)) => ["stage_id", "contract_id"]
      _ => ["stage_id"]
    }
    entries.push({
      stage_id: stage.stage_id,
      artifact_ref,
      input_schema_ref,
      schema_source_ref: stage.product_id + "/schemas/fixture.schema.json",
      schema_digest,
      payload_digest: digest,
      required_top_level_fields,
      constant_top_level_fields,
      validation_scope: "fixture-test",
    })
    payloads.push({ artifact_ref, payload_digest: digest, payload })
  }
  let materialization : @integration.RoboticsRequestMaterializationV1 = {
    contract_id: "moonfind.robotics-request-materialization.v1",
    graph_id: desired.graph_id,
    graph_source_digest: desired.source_digest,
    fixture_only: true,
    fixture_notice: "synthetic",
    generated_at: "2026-07-31T00:00:00Z",
    validation_engine: "fixture-test",
    complete: true,
    unresolved_fields: [],
    entries,
  }
  assert_true(
    @integration.validate_robotics_request_materialization(
      desired, materialization, payloads,
    ).is_empty(),
  )
  let omitted_artifact = payloads[payloads.length() - 1].artifact_ref
  let missing = payloads.filter(payload => {
    payload.artifact_ref != omitted_artifact
  })
  let issues = @integration.validate_robotics_request_materialization(
    desired, materialization, missing,
  )
  assert_true(issues.contains("materialization-cardinality-mismatch"))
  assert_true(issues.any(issue => issue.has_suffix(":request-payload-missing")))
}
