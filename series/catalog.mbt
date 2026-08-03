///|
/// A user-facing phase in a repeatable MoonSuite series workflow.
pub(all) struct SeriesPhaseV1 {
  phase_id : String
  title : String
  outcome : String
  product_ids : Array[String]
  stage_ids : Array[String]
} derive(Debug, Eq, ToJson)

///|
/// A curated cross-product scenario. The embedded desired graph remains intent:
/// MoonFlow may execute it only after exact capability projection succeeds.
pub(all) struct SeriesUseCaseV1 {
  contract_id : String
  use_case_id : String
  title : String
  summary : String
  primary_user : String
  primary_action : String
  completion_statement : String
  phases : Array[SeriesPhaseV1]
  graph : @integration.DesiredCapabilityGraphV2
} derive(Debug, Eq, ToJson)

///|
fn stage(
  stage_id : String,
  product_id : String,
  operation_ref : String,
  authority : String,
  input_schema_ref : String,
  output_schema_ref : String,
  required_claim : String,
  acceptance : String,
  artifact_ref : String,
  depends_on : Array[String],
  execution_role : String?,
  execution_config : Json?,
) -> @integration.DesiredCapabilityStageV2 {
  {
    stage_id,
    declaration_id: stage_id + "-series-v1",
    product_id,
    desired_operation_ref: Some(operation_ref),
    desired_tool_hint: operation_ref,
    execution_role,
    execution_config,
    requested_authority: authority,
    input_schema_ref: Some(input_schema_ref),
    output_schema_ref: Some(output_schema_ref),
    required_claim,
    acceptance_criteria: [acceptance],
    input_artifacts: [artifact_ref],
    timeout_ms: 600000,
    depends_on,
  }
}

///|
fn mooncast_creative_revise(
  stage_id : String,
  artifact_kind : String,
  depends_on : Array[String],
  acceptance : String,
) -> @integration.DesiredCapabilityStageV2 {
  stage(
    stage_id,
    "mooncast",
    "mooncast/creative.artifact.revise@0.2.0",
    "workspace-mutation",
    "mooncast/creative-revision-request@1.0.0",
    "mooncast/creative-artifact@1.0.0",
    "execution-result",
    acceptance,
    "requests/" + stage_id + ".creative-revision-request.json",
    depends_on,
    None,
    Some({ "artifact_kind": artifact_kind }),
  )
}

///|
fn mooncast_creative_decide(
  stage_id : String,
  artifact_kind : String,
  depends_on : Array[String],
  acceptance : String,
) -> @integration.DesiredCapabilityStageV2 {
  stage(
    stage_id,
    "mooncast",
    "mooncast/creative.artifact.decide@0.2.0",
    "workspace-mutation",
    "mooncast/creative-decision-request@1.0.0",
    "mooncast/creative-decision@1.0.0",
    "execution-result",
    acceptance,
    "requests/" + stage_id + ".creative-decision-request.json",
    depends_on,
    None,
    Some({ "artifact_kind": artifact_kind, "named_decider_required": true }),
  )
}

///|
fn mooncast_asset_generate(
  stage_id : String,
  asset_kind : String,
  depends_on : Array[String],
  acceptance : String,
) -> @integration.DesiredCapabilityStageV2 {
  stage(
    stage_id,
    "mooncast",
    "mooncast/asset-factory.generate@0.2.0",
    "external-effect",
    "mooncast/asset-factory-plan@1.0.0",
    "mooncast/asset-generation-variant@1.0.0",
    "digital-artifact",
    acceptance,
    "requests/" + stage_id + ".asset-factory-plan.json",
    depends_on,
    None,
    Some({
      "asset_kind": asset_kind,
      "provider_authority_required": true,
      "authority_grant_contract": "mooncast.host-authority-grant.v1",
      "publication": false,
    }),
  )
}

///|
fn mooncast_asset_review(
  stage_id : String,
  asset_kind : String,
  depends_on : Array[String],
  acceptance : String,
) -> @integration.DesiredCapabilityStageV2 {
  stage(
    stage_id,
    "mooncast",
    "mooncast/asset-factory.review@0.2.0",
    "workspace-mutation",
    "mooncast/asset-qc-finding@1.0.0",
    "mooncast/approved-reusable-asset@1.0.0",
    "accepted-knowledge",
    acceptance,
    "requests/" + stage_id + ".asset-qc-finding.json",
    depends_on,
    None,
    Some({
      "asset_kind": asset_kind,
      "named_decider_required": true,
      "required_qc_dimensions": [
        "technical", "identity", "continuity", "rights", "safety",
      ],
      "variant_dependency_required": true,
      "auxiliary_artifact_materialization_required": true,
    }),
  )
}

///|
fn lunar_habitat_graph() -> @integration.DesiredCapabilityGraphV2 {
  {
    contract_id: "moonfind.desired-capability-graph.v2",
    graph_id: "moonfind-lunar-habitat-decision-series-v1",
    book_id: "lunar-habitat-decision-series",
    declaration_revision: "series-v2-known-intake-gap",
    source_digest: "sha256:3c95e516d9d47301a7312cccd69d2fa257a45d7a58fc949c41474508b1b2fab5",
    support_topology: Some({
      "execution_engine": "moonflow",
      "authority_and_provider_resolution": "moongate",
      "agent_runtime": "moonclaw",
      "visible_workspace": "moondesk",
      "source_ref": "workflows/lunar-habitat-decision-series-source.v1.json",
      "rule": "support products are not domain stages",
    }),
    intentional_exclusions: Some([
      {
        "product_id": "moonfish",
        "reason": "a securities recommendation is unrelated to the habitat decision package",
      },
      {
        "capability": "physical robot command",
        "reason": "the workflow stops at observed digital readiness",
      },
      {
        "capability": "publication",
        "reason": "the animatic is an internal decision artifact",
      },
      {
        "capability": "commercial master",
        "reason": "real-provider footage and customer acceptance remain separate MoonCast gates",
      },
    ]),
    stages: [
      stage(
        "capture-commission",
        "moonbook",
        "moonbook/wiki.requirements.prepare@0.1.0",
        "workspace-mutation",
        "moonbook/wiki-requirements-prepare@1.0.0",
        "moonbook/wiki-requirements-packet@1.0.0",
        "digital-artifact",
        "owner outcome, constraints, unknowns, budget boundary, and acceptance method are explicit",
        "requests/capture-commission.wiki-requirements-prepare.json",
        [],
        Some("wiki"),
        Some({ "owner_intent_required": true }),
      ),
      stage(
        "owner-commission-review",
        "moonchat",
        "moonchat/conversation.review.record@0.1.0",
        "workspace-mutation",
        "moonchat/conversation-review-bundle@1.0.0",
        "moonchat/conversation-review-record@1.0.0",
        "accepted-knowledge",
        "the named owner decides every unresolved requirement",
        "requests/owner-commission-review.conversation-review-bundle.json",
        ["capture-commission"],
        None,
        Some({
          "review_kind": "owner-commission",
          "named_decider_required": true,
        }),
      ),
      stage(
        "requirements-agent-check",
        "moonclaw",
        "moonclaw/agent.goal.execute@0.1.5",
        "workspace-mutation",
        "moonclaw/agent-goal-execution-request@1.0.0",
        "moonclaw/agent-goal-execution-receipt@1.0.0",
        "digital-artifact",
        "the wiki role records remaining gaps without self-approving the commission",
        "requests/requirements-agent-check.agent-goal-execution-request.json",
        ["owner-commission-review"],
        Some("wiki"),
        Some({ "model": "gpt-5.6-sol", "runtime": "moonclaw" }),
      ),
      stage(
        "research-habitat-evidence",
        "moonfind",
        "moonfind/research.cross-paper-synthesize@0.1.0",
        "sandbox-execution",
        "moonfind/research-run@1.0.0",
        "moonfind/moontown-research-scenario@1.0.0",
        "research-evidence",
        "full-text evidence is isolated, cited, cross-paper, and falsifiable",
        "requests/research-habitat-evidence.research-run.json",
        ["requirements-agent-check"],
        None,
        None,
      ),
      stage(
        "challenge-site-strategy",
        "moontown",
        "moontown/civic.communication.synthesize@0.1.0",
        "workspace-mutation",
        "moontown/civic-communication-handoff@1.0.0",
        "moontown/civic-synthesis-result@1.0.0",
        "execution-result",
        "independent participant books expose site, safety, logistics, and operations disagreements",
        "requests/challenge-site-strategy.civic-communication-handoff.json",
        ["research-habitat-evidence"],
        None,
        None,
      ),
      stage(
        "accept-evidence-baseline",
        "moonchat",
        "moonchat/conversation.review.record@0.1.0",
        "workspace-mutation",
        "moonchat/conversation-review-bundle@1.0.0",
        "moonchat/conversation-review-record@1.0.0",
        "accepted-knowledge",
        "a named reviewer accepts or defers each claim used by planning",
        "requests/accept-evidence-baseline.conversation-review-bundle.json",
        ["challenge-site-strategy"],
        None,
        Some({
          "review_kind": "evidence-baseline",
          "named_decider_required": true,
        }),
      ),
      stage(
        "plan-habitat-program",
        "moonproj",
        "moonproj/project.plan.prepare@0.1.0",
        "workspace-mutation",
        "moonproj/project-plan-request@1.0.0",
        "moonproj/project-plan-artifact@1.0.0",
        "digital-artifact",
        "milestones, interfaces, cost ceiling, risks, evidence gates, and owners are explicit",
        "requests/plan-habitat-program.project-plan-request.json",
        ["accept-evidence-baseline"],
        None,
        None,
      ),
      stage(
        "design-habitat-digital-twin",
        "moonmold",
        "moonmold/spatial.operation.execute@0.2.0",
        "workspace-mutation",
        "moonmold/spatial-operation-request@1.0.0",
        "moonmold/spatial-operation-receipt@1.0.0",
        "digital-artifact",
        "the habitat representation preserves dimensions, assumptions, losses, and lineage",
        "requests/design-habitat-digital-twin.spatial-operation-request.json",
        ["plan-habitat-program"],
        None,
        None,
      ),
      stage(
        "simulate-lunar-site-mission",
        "moonmoon",
        "moonmoon/simulation.robot-mission@0.1.0",
        "sandbox-execution",
        "moonmoon/robot-mission-run-request@1.0.0",
        "moonmoon/mission-simulation-receipt@1.0.0",
        "calibrated-digital-twin",
        "the digital mission records terrain, environment, route, uncertainty, and calibration limits",
        "requests/simulate-lunar-site-mission.robot-mission-run-request.json",
        ["plan-habitat-program", "design-habitat-digital-twin"],
        None,
        None,
      ),
      stage(
        "integrate-construction-robot",
        "moonrobo",
        "moonrobo/robot.integrate-digital-model@0.2.0",
        "workspace-mutation",
        "moonrobo/robot-design@1.0.0",
        "moonrobo/digital-model-integration-receipt@1.0.0",
        "digital-artifact",
        "the robot and habitat models share exact frames, interfaces, and evidence identity",
        "requests/integrate-construction-robot.robot-design.json",
        ["design-habitat-digital-twin"],
        None,
        None,
      ),
      stage(
        "inspect-digital-readiness",
        "moonrobo",
        "moonrobo/robot.readiness.inspect@0.2.0",
        "observe",
        "moonrobo/robobook-ref@1.0.0",
        "moonrobo/readiness-observation@1.0.0",
        "observation",
        "readiness blockers are evidence-backed and no physical command is issued",
        "requests/inspect-digital-readiness.robobook-ref.json",
        ["simulate-lunar-site-mission", "integrate-construction-robot"],
        None,
        None,
      ),
      stage(
        "resolve-review-visuals",
        "moonvis",
        "moonvis/visual.asset-bundle.resolve@0.1.0",
        "workspace-mutation",
        "moonvis/visual-asset-bundle-request@1.0.0",
        "moonvis/visual-asset-bundle-manifest@1.0.0",
        "digital-artifact",
        "the review visual bundle is exact, current, digest-bound, and rights-pending",
        "requests/resolve-review-visuals.visual-asset-bundle-request.json",
        ["design-habitat-digital-twin", "simulate-lunar-site-mission"],
        None,
        None,
      ),
      stage(
        "draft-episode-narrative",
        "moonclaw",
        "moonclaw/agent.goal.execute@0.1.5",
        "workspace-mutation",
        "moonclaw/agent-goal-execution-request@1.0.0",
        "moonclaw/agent-goal-execution-receipt@1.0.0",
        "digital-artifact",
        "the production role creates a three-minute evidence-bound narrative without inventing readiness",
        "requests/draft-episode-narrative.agent-goal-execution-request.json",
        [
          "challenge-site-strategy", "inspect-digital-readiness", "resolve-review-visuals",
        ],
        Some("mooncode"),
        Some({ "model": "gpt-5.6-sol", "runtime": "moonclaw" }),
      ),
      stage(
        "seed-approved-review-episode",
        "mooncast",
        "mooncast/needs-intake.approve-and-seed@0.3.0",
        "workspace-mutation",
        "mooncast/moonwiki-needs-export@1.0.0",
        "mooncast/project-needs-intake-binding@1.0.0",
        "execution-result",
        "a named intake decision seeds the 180-second project with accepted qualification, owner, budget, and rights facts; projection must block until Mooncast publishes this operation",
        "requests/seed-approved-review-episode.moonwiki-needs-export.json",
        [
          "capture-commission", "owner-commission-review", "accept-evidence-baseline",
          "draft-episode-narrative",
        ],
        None,
        Some({
          "format": "lunar-habitat-internal-review",
          "target_duration_seconds": 180,
          "named_intake_approval_required": true,
          "dependency_evidence_binding_required": true,
          "rights_decision_required": true,
          "publication": false,
          "commercial_master": false,
        }),
      ),
      mooncast_creative_revise(
        "revise-review-brief",
        "brief",
        ["seed-approved-review-episode"],
        "the exact 180-second internal-review brief preserves the owner outcome, accepted evidence, claim limits, budget, and exclusions",
      ),
      mooncast_creative_decide(
        "approve-review-brief",
        "brief",
        ["revise-review-brief"],
        "a named producer approves the exact brief revision and the operation returns the resulting current G0 receipt without granting provider or publication authority",
      ),
      mooncast_creative_revise(
        "revise-review-rights",
        "rights-ledger",
        ["approve-review-brief"],
        "the rights ledger names every visual, voice, music, font, style, likeness, data-use, and model-provider restriction",
      ),
      mooncast_creative_decide(
        "approve-review-rights",
        "rights-ledger",
        ["revise-review-rights"],
        "a named rights reviewer clears or rejects the exact ledger; an unresolved item blocks the series",
      ),
      mooncast_creative_revise(
        "revise-habitat-bible",
        "ip-bible",
        ["approve-review-rights"],
        "the habitat bible fixes approved structures, equipment, palette, spatial rules, continuity constraints, and negative references",
      ),
      mooncast_creative_decide(
        "approve-habitat-bible",
        "ip-bible",
        ["revise-habitat-bible"],
        "a named creative reviewer approves the exact habitat bible and the operation returns the resulting current G1 receipt only while rights remain cleared",
      ),
      mooncast_creative_revise(
        "revise-review-script",
        "script",
        ["approve-review-rights", "approve-habitat-bible"],
        "the three-minute script separates reported evidence, calculations, inference, uncertainty, and the owner decision",
      ),
      mooncast_creative_decide(
        "approve-review-script",
        "script",
        ["revise-review-script"],
        "a named creative reviewer approves the exact script and target duration",
      ),
      mooncast_creative_revise(
        "revise-review-claims",
        "claims-ledger",
        ["approve-review-script"],
        "every spoken or visual readiness claim is bound to accepted evidence, a ceiling, and contradictory evidence",
      ),
      mooncast_creative_decide(
        "approve-review-claims",
        "claims-ledger",
        ["revise-review-claims"],
        "a named evidence reviewer approves the exact claims ledger and rejects unsupported physical-readiness language",
      ),
      mooncast_creative_revise(
        "revise-review-storyboard",
        "storyboard",
        ["approve-review-claims"],
        "the storyboard binds every panel to the current script, claim, source visual, duration, caption, and transition",
      ),
      mooncast_creative_decide(
        "approve-review-storyboard",
        "storyboard",
        ["revise-review-storyboard"],
        "a named creative reviewer approves the exact storyboard and the operation returns the resulting current G2 receipt only while script, claims, bible, and rights bindings remain current",
      ),
      stage(
        "plan-review-assets",
        "mooncast",
        "mooncast/asset-factory.plan.record@0.2.0",
        "workspace-mutation",
        "mooncast/asset-factory-plan@1.0.0",
        "mooncast/asset-factory-plan@1.0.0",
        "digital-artifact",
        "a bounded reusable-asset plan covers required habitat visuals, voice, and music with provider, retry, rights, and cost ceilings",
        "requests/plan-review-assets.asset-factory-plan.json",
        ["approve-review-storyboard", "resolve-review-visuals"],
        None,
        Some({ "publication": false, "commercial_quality_claim": false }),
      ),
      mooncast_asset_generate(
        "generate-review-visual",
        "visual",
        ["plan-review-assets"],
        "a bounded habitat visual variant is generated only through a permitted provider or deterministic qualification port with an explicit provider grant",
      ),
      mooncast_asset_generate(
        "generate-review-voice",
        "voice",
        ["plan-review-assets"],
        "a bounded temporary narration variant is generated with voice and likeness rights, cost, provider, and retry limits",
      ),
      mooncast_asset_generate(
        "generate-review-music",
        "music",
        ["plan-review-assets"],
        "a bounded temporary music variant is generated with exact music rights, cost, provider, and retry limits",
      ),
      mooncast_asset_review(
        "approve-review-visual-asset",
        "visual",
        ["generate-review-visual"],
        "a named reviewer accepts the exact visual only after its variant and five technical, identity, continuity, rights, and safety findings are bound",
      ),
      mooncast_asset_review(
        "approve-review-voice-asset",
        "voice",
        ["generate-review-voice"],
        "a named reviewer accepts the exact voice only after its variant and five technical, identity, continuity, rights, and safety findings are bound",
      ),
      mooncast_asset_review(
        "approve-review-music-asset",
        "music",
        ["generate-review-music"],
        "a named reviewer accepts the exact music only after its variant and five technical, identity, continuity, rights, and safety findings are bound",
      ),
      stage(
        "prepare-animatic-plan",
        "mooncast",
        "mooncast/animatic.plan.record@0.2.0",
        "workspace-mutation",
        "mooncast/animatic-plan@1.0.0",
        "mooncast/animatic-plan@1.0.0",
        "digital-artifact",
        "the timed plan binds shots, temporary audio, cost ceiling, and source assets",
        "requests/prepare-animatic-plan.animatic-plan.json",
        [
          "approve-review-storyboard", "approve-review-visual-asset", "approve-review-voice-asset",
          "approve-review-music-asset",
        ],
        None,
        Some({
          "target_duration_seconds": 180,
          "panel_count": 15,
          "panel_duration_seconds": 12,
          "required_approved_asset_kinds": ["visual", "voice", "music"],
          "exact_creative_references_required": [
            "ip-bible", "script", "storyboard",
          ],
          "publication": false,
          "commercial_master": false,
        }),
      ),
      stage(
        "render-review-animatic",
        "mooncast",
        "mooncast/animatic.render@0.2.0",
        "sandbox-execution",
        "mooncast/animatic-plan@1.0.0",
        "mooncast/rendered-animatic@1.0.0",
        "digital-artifact",
        "the deterministic internal animatic is rendered with audio, subtitles, labels, and provenance",
        "requests/render-review-animatic.animatic-plan.json",
        ["prepare-animatic-plan"],
        None,
        Some({
          "host_authority_grant": "sandbox-process",
          "network_effect": false,
          "publication": false,
        }),
      ),
      stage(
        "approve-review-animatic",
        "mooncast",
        "mooncast/animatic.approve@0.2.0",
        "workspace-mutation",
        "mooncast/rendered-animatic@1.0.0",
        "mooncast/rendered-animatic-approval@1.0.0",
        "accepted-knowledge",
        "a named reviewer accepts or rejects the exact internal animatic and budget boundary",
        "requests/approve-review-animatic.rendered-animatic.json",
        ["render-review-animatic"],
        None,
        Some({ "named_decider_required": true }),
      ),
      stage(
        "owner-animatic-decision",
        "moonchat",
        "moonchat/conversation.review.record@0.1.0",
        "workspace-mutation",
        "moonchat/conversation-review-bundle@1.0.0",
        "moonchat/conversation-review-record@1.0.0",
        "accepted-knowledge",
        "the named owner approves, rejects, or requests revision of the exact internal animatic without client-portal, publication, or delivery-master authority",
        "requests/owner-animatic-decision.conversation-review-bundle.json",
        ["approve-review-animatic"],
        None,
        Some({
          "review_kind": "internal-animatic",
          "named_decider_required": true,
        }),
      ),
      stage(
        "bookkeeper-close-loop",
        "moonbook",
        "moonbook/bookkeeper.outcome.close@0.1.0",
        "workspace-mutation",
        "moonbook/bookkeeper-product-outcome-closure@1.0.0",
        "moonbook/bookkeeper-product-outcome-closure-receipt@1.0.0",
        "digital-artifact",
        "Bookkeeper records the outcome, citations, and Three-Gap proposal without self-activating a capability",
        "requests/bookkeeper-close-loop.bookkeeper-product-outcome-closure.json",
        ["owner-animatic-decision", "inspect-digital-readiness"],
        Some("bookkeeper"),
        Some({ "three_gap_assessments": 1, "self_approval_forbidden": true }),
      ),
    ],
  }
}

///|
pub fn lunar_habitat_decision_series() -> SeriesUseCaseV1 {
  {
    contract_id: "moonsuite.series-use-case.v1",
    use_case_id: "lunar-habitat-decision-series",
    title: "Lunar Habitat Decision Series",
    summary: "Turn an owner commission into cited research, a governed digital habitat and robot-readiness package, and a reviewable three-minute internal animatic.",
    primary_user: "program owner",
    primary_action: "Review the commission and start evidence gathering",
    completion_statement: "The named owner has a review decision, exact digital evidence, an approved or rejected internal animatic, and Bookkeeper Three-Gap closure; no physical action or publication occurred.",
    phases: [
      {
        phase_id: "understand",
        title: "Understand",
        outcome: "Accepted commission and explicit unknowns",
        product_ids: ["moonbook", "moonchat", "moonclaw"],
        stage_ids: [
          "capture-commission", "owner-commission-review", "requirements-agent-check",
        ],
      },
      {
        phase_id: "research",
        title: "Research",
        outcome: "Cited evidence and challenged assumptions",
        product_ids: ["moonfind", "moontown", "moonchat"],
        stage_ids: [
          "research-habitat-evidence", "challenge-site-strategy", "accept-evidence-baseline",
        ],
      },
      {
        phase_id: "plan",
        title: "Plan",
        outcome: "Budgeted program with evidence gates",
        product_ids: ["moonproj"],
        stage_ids: ["plan-habitat-program"],
      },
      {
        phase_id: "model",
        title: "Model",
        outcome: "Digital habitat, simulated site, and observed robot readiness",
        product_ids: ["moonmold", "moonmoon", "moonrobo"],
        stage_ids: [
          "design-habitat-digital-twin", "simulate-lunar-site-mission", "integrate-construction-robot",
          "inspect-digital-readiness",
        ],
      },
      {
        phase_id: "explain",
        title: "Explain",
        outcome: "Evidence-bound three-minute internal animatic",
        product_ids: ["moonvis", "moonclaw", "mooncast"],
        stage_ids: [
          "resolve-review-visuals", "draft-episode-narrative", "seed-approved-review-episode",
          "revise-review-brief", "approve-review-brief", "revise-review-rights",
          "approve-review-rights", "revise-habitat-bible", "approve-habitat-bible",
          "revise-review-script", "approve-review-script", "revise-review-claims",
          "approve-review-claims", "revise-review-storyboard", "approve-review-storyboard",
          "plan-review-assets", "generate-review-visual", "generate-review-voice",
          "generate-review-music", "approve-review-visual-asset", "approve-review-voice-asset",
          "approve-review-music-asset", "prepare-animatic-plan", "render-review-animatic",
          "approve-review-animatic",
        ],
      },
      {
        phase_id: "decide-and-learn",
        title: "Decide & learn",
        outcome: "Named decision and reviewed Three-Gap closure",
        product_ids: ["moonchat", "moonbook"],
        stage_ids: ["owner-animatic-decision", "bookkeeper-close-loop"],
      },
    ],
    graph: lunar_habitat_graph(),
  }
}

///|
pub fn catalog() -> Array[SeriesUseCaseV1] {
  [lunar_habitat_decision_series()]
}

///|
pub fn find(use_case_id : String) -> SeriesUseCaseV1? {
  for item in catalog() {
    if item.use_case_id == use_case_id {
      return Some(item)
    }
  }
  None
}

///|
pub fn validate(use_case : SeriesUseCaseV1) -> Array[String] {
  let issues : Array[String] = []
  if use_case.contract_id != "moonsuite.series-use-case.v1" {
    issues.push("unsupported series use-case contract")
  }
  if use_case.graph.contract_id != "moonfind.desired-capability-graph.v2" {
    issues.push("series graph must remain desired capability intent")
  }
  let stage_ids : Map[String, Unit] = Map([])
  for item in use_case.graph.stages {
    if stage_ids.contains(item.stage_id) {
      issues.push("duplicate stage: " + item.stage_id)
    } else {
      stage_ids[item.stage_id] = ()
    }
    match item.desired_operation_ref {
      Some(operation) =>
        if !operation.contains("/") || !operation.contains("@") {
          issues.push("unversioned operation: " + item.stage_id)
        }
      None => issues.push("missing operation: " + item.stage_id)
    }
    for dependency in item.depends_on {
      if !stage_ids.contains(dependency) {
        issues.push(
          "dependency must precede stage: " +
          item.stage_id +
          " -> " +
          dependency,
        )
      }
    }
  }
  let covered : Map[String, Unit] = Map([])
  for phase in use_case.phases {
    for stage_id in phase.stage_ids {
      if !stage_ids.contains(stage_id) {
        issues.push("phase references unknown stage: " + stage_id)
      }
      if covered.contains(stage_id) {
        issues.push("stage appears in multiple phases: " + stage_id)
      } else {
        covered[stage_id] = ()
      }
    }
  }
  if covered.length() != stage_ids.length() {
    issues.push("every series stage must appear in exactly one visible phase")
  }
  issues
}
