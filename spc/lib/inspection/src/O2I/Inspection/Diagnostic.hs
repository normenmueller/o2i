{-# LANGUAGE OverloadedStrings #-}

-- | Closed, deterministic diagnostic domain shared by adapters and reports.
module O2I.Inspection.Diagnostic
  ( InspectionStage(..)
  , DiagnosticSeverity(..)
  , DiagnosticDisposition(..)
  , DiagnosticCode(..)
  , DiagnosticId(..)
  , DiagnosticAtom(..)
  , DiagnosticSubject(..)
  , DiagnosticSpec(..)
  , Diagnostic(..)
  , Diagnostics
  , diagnosticFromSpec
  , diagnosticFromLocated
  , diagnosticsFromLocated
  , normalizeDiagnostics
  , diagnosticsList
  , structuralDefectSpec
  , semanticDefectSpec
  , traceabilityDefectSpec
  , readinessDefectSpec
  , evidenceDefectSpec
  ) where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import O2I
import O2I.Inspection.Provenance

-- | Canonical validation-stage order.
data InspectionStage
  = DecodeStage
  | ViewScopeStage
  | ProfileStage
  | StructureStage
  | SemanticsStage
  | TraceabilityStage
  | ReadinessStage
  | EvidenceStage
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Human diagnostic level; validation findings are normally errors.
data DiagnosticSeverity
  = DebugSeverity
  | InfoSeverity
  | WarningSeverity
  | ErrorSeverity
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Whether a diagnostic describes model validity or process integrity.
data DiagnosticDisposition
  = ModelFinding
  | ProcessFailure
  deriving (Eq, Ord, Show)

-- | Stable machine-readable diagnostic code.
newtype DiagnosticCode = DiagnosticCode
  { diagnosticCodeText :: Text
  } deriving (Eq, Ord, Show)

-- | Stable identity of one normalized diagnostic occurrence.
newtype DiagnosticId = DiagnosticId
  { diagnosticIdText :: Text
  } deriving (Eq, Ord, Show)

-- | Closed machine-data scalar.
data DiagnosticAtom
  = DiagnosticText Text
  | DiagnosticInteger Integer
  | DiagnosticBoolean Bool
  deriving (Eq, Ord, Show)

-- | Structured subject independent of human prose.
data DiagnosticSubject = DiagnosticSubject
  { subjectKind :: Text
  , subjectIdentifier :: Text
  } deriving (Eq, Ord, Show)

-- | Total projection target of one closed defect constructor.
data DiagnosticSpec = DiagnosticSpec
  { specCode :: DiagnosticCode
  , specStage :: InspectionStage
  , specSeverity :: DiagnosticSeverity
  , specDisposition :: DiagnosticDisposition
  , specMessage :: Text
  , specSubjects :: [DiagnosticSubject]
  , specData :: Map Text DiagnosticAtom
  } deriving (Eq, Show)

-- | Normalized diagnostic retained in reports.
data Diagnostic = Diagnostic
  { diagnosticId :: DiagnosticId
  , diagnosticCode :: DiagnosticCode
  , diagnosticStage :: InspectionStage
  , diagnosticSeverity :: DiagnosticSeverity
  , diagnosticDisposition :: DiagnosticDisposition
  , diagnosticMessage :: Text
  , diagnosticSubjects :: [DiagnosticSubject]
  , diagnosticLocations :: [SourceLocation]
  , diagnosticData :: Map Text DiagnosticAtom
  } deriving (Eq, Show)

-- | Deterministically ordered diagnostics.
newtype Diagnostics =
  Diagnostics [Diagnostic]
  deriving (Eq, Show)

-- | Normalize a specification with zero or more source locations.
diagnosticFromSpec :: [SourceLocation] -> DiagnosticSpec -> Diagnostic
diagnosticFromSpec locations specification =
  Diagnostic
    { diagnosticId = diagnosticIdentity specification locations
    , diagnosticCode = specCode specification
    , diagnosticStage = specStage specification
    , diagnosticSeverity = specSeverity specification
    , diagnosticDisposition = specDisposition specification
    , diagnosticMessage = specMessage specification
    , diagnosticSubjects = specSubjects specification
    , diagnosticLocations = locations
    , diagnosticData = specData specification
    }

-- | Normalize one located closed defect.
diagnosticFromLocated ::
     (defect -> DiagnosticSpec) -> Located defect -> Diagnostic
diagnosticFromLocated specification located =
  diagnosticFromSpec [locatedAt located] (specification (locatedValue located))

-- | Normalize a non-empty collection of located defects.
diagnosticsFromLocated ::
     (defect -> DiagnosticSpec) -> NonEmpty (Located defect) -> Diagnostics
diagnosticsFromLocated specification =
  normalizeDiagnostics
    . map (diagnosticFromLocated specification)
    . NonEmpty.toList

-- | Sort diagnostics by stage, code, subject, and source occurrence.
normalizeDiagnostics :: [Diagnostic] -> Diagnostics
normalizeDiagnostics = Diagnostics . sortOn diagnosticSortKey

-- | Read diagnostics in canonical order.
diagnosticsList :: Diagnostics -> [Diagnostic]
diagnosticsList (Diagnostics diagnostics) = diagnostics

diagnosticSortKey :: Diagnostic -> (Int, Text, Text, Text)
diagnosticSortKey diagnostic =
  ( fromEnum (diagnosticStage diagnostic)
  , diagnosticCodeText (diagnosticCode diagnostic)
  , subjectsKey (diagnosticSubjects diagnostic)
  , locationsKey (diagnosticLocations diagnostic))

diagnosticIdentity :: DiagnosticSpec -> [SourceLocation] -> DiagnosticId
diagnosticIdentity specification locations =
  DiagnosticId
    (Text.intercalate
       "|"
       [ diagnosticCodeText (specCode specification)
       , subjectsKey (specSubjects specification)
       , locationsKey locations
       ])

subjectsKey :: [DiagnosticSubject] -> Text
subjectsKey =
  Text.intercalate ","
    . map (\subject -> subjectKind subject <> ":" <> subjectIdentifier subject)

locationsKey :: [SourceLocation] -> Text
locationsKey = Text.intercalate "," . map locationKey

locationKey :: SourceLocation -> Text
locationKey location =
  Text.intercalate
    ":"
    [ sourceDisplayLabel source
    , sourceHashText (sourceSha256 source)
    , Text.intercalate
        "/"
        (map pathKey (NonEmpty.toList (locationPath location)))
    , targetKey (locationTarget location)
    , maybe "" spanKey (locationSpan location)
    ]
  where
    source = locationSource location

pathKey :: PathStep -> Text
pathKey step =
  qNameKey (pathStepName step)
    <> "["
    <> Text.pack (show (pathStepOrdinal step))
    <> "]"

qNameKey :: ExpandedQName -> Text
qNameKey name =
  "{" <> maybe "" id (qNameNamespace name) <> "}" <> qNameLocalName name

targetKey :: LocationTarget -> Text
targetKey target =
  case target of
    ElementTarget -> "element"
    AttributeTarget name -> "attribute=" <> qNameKey name
    PropertyTarget key -> "property=" <> key
    TextFieldTarget name -> "text=" <> qNameKey name

spanKey :: SourceSpan -> Text
spanKey sourceSpan =
  Text.intercalate
    ","
    (map
       (Text.pack . show)
       [ spanStartLine sourceSpan
       , spanStartColumn sourceSpan
       , spanEndLine sourceSpan
       , spanEndColumn sourceSpan
       ])

-- | Total diagnostic mapping for every structural model defect.
structuralDefectSpec :: StructuralError -> DiagnosticSpec
structuralDefectSpec defect =
  case defect of
    DuplicateNodeId identifier ->
      coreSpec
        StructureStage
        "o2i.structure.node-id-duplicate"
        "A node identifier is declared more than once."
        [nodeSubject identifier]
    DuplicateEdge edge ->
      coreSpec
        StructureStage
        "o2i.structure.edge-duplicate"
        "The same directed O2I relation is declared more than once."
        [edgeSubject edge]
    UnknownOwner identifier owner ->
      coreSpec
        StructureStage
        "o2i.structure.owner-unknown"
        "An owned node refers to an unknown Context."
        [nodeSubject identifier, ownerSubject owner]
    InvalidPrimitiveInterpretation identifier context primitive ->
      coreSpec
        StructureStage
        "o2i.structure.interpretation-invalid"
        "A Primitive is not interpretable in its owning Context."
        [ nodeSubject identifier
        , valueSubject "context" context
        , valueSubject "primitive" primitive
        ]
    InvalidStructuringContext identifier context structuring ->
      coreSpec
        StructureStage
        "o2i.structure.structuring-context-invalid"
        "A Structuring element has no role in its owning Context."
        [ nodeSubject identifier
        , valueSubject "context" context
        , valueSubject "structuring" structuring
        ]
    UnknownEdgeEndpoint edge identifier ->
      coreSpec
        StructureStage
        "o2i.structure.endpoint-unknown"
        "A relation endpoint refers to an unknown node."
        [edgeSubject edge, nodeSubject identifier]
    UnknownRelation relation ->
      coreSpec
        StructureStage
        "o2i.structure.relation-unknown"
        "A relation name is not registered by O2I."
        [relationSubject relation]
    InvalidRelationEndpointKinds edge fromKind toKind ->
      coreSpec
        StructureStage
        "o2i.structure.relation-endpoint-kinds-invalid"
        "Relation endpoint kinds do not match the relation registry."
        [ edgeSubject edge
        , valueSubject "source-kind" fromKind
        , valueSubject "target-kind" toKind
        ]
    PerformanceDimensionMembershipOwnerMismatch edge dimensionOwner memberOwner ->
      coreSpec
        StructureStage
        "o2i.structure.membership-owner-mismatch"
        "A PerformanceDimension and its member have different owners."
        [ edgeSubject edge
        , DiagnosticSubject "dimension-owner" (rawNodeIdText dimensionOwner)
        , DiagnosticSubject "member-owner" (rawNodeIdText memberOwner)
        ]

-- | Total diagnostic mapping for every global semantic invariant defect.
semanticDefectSpec :: ModelInvariantError -> DiagnosticSpec
semanticDefectSpec defect =
  case defect of
    SituationWithoutConstitutingAnchor situation ->
      semantic
        "o2i.semantics.situation-unconstituted"
        "A Situation has no constituting anchor."
        [nodeSubject situation]
    NeedWithoutDriver need ->
      semantic
        "o2i.semantics.need-driver-missing"
        "A Need has no Driver."
        [nodeSubject need]
    NeedWithoutObjective need ->
      semantic
        "o2i.semantics.need-objective-missing"
        "A Need has no Objective."
        [nodeSubject need]
    NeedWithoutSurfacingSituation need ->
      semantic
        "o2i.semantics.need-unsituated"
        "No Situation surfaces the Need."
        [nodeSubject need]
    UnanchoredNeedDriver need driver ->
      semantic
        "o2i.semantics.need-driver-unanchored"
        "A Need Driver is not attached to a constituent Situation anchor."
        [nodeSubject need, nodeSubject driver]
    UngroundedNeedObjective need objective ->
      semantic
        "o2i.semantics.need-objective-ungrounded"
        "A Need Objective is not grounded by a Driver of the same Need."
        [nodeSubject need, nodeSubject objective]
    StrategyWithoutFormulation strategy ->
      semantic
        "o2i.semantics.formulation-missing"
        "A Strategy has no supplied formulation."
        [nodeSubject strategy]
    DuplicateStrategyFormulation strategy ->
      semantic
        "o2i.semantics.formulation-duplicate"
        "More than one formulation targets the same Strategy."
        [nodeSubject strategy]
    UnknownFormulationStrategy strategy ->
      semantic
        "o2i.semantics.formulation-strategy-unknown"
        "A formulation targets an unknown node."
        [nodeSubject strategy]
    FormulationForNonStrategy identifier kind ->
      semantic
        "o2i.semantics.formulation-target-invalid"
        "A formulation target is not a Strategy Context."
        [nodeSubject identifier, valueSubject "node-kind" kind]
    EmptyStrategyText strategy field ->
      semantic
        "o2i.semantics.formulation-text-empty"
        "A mandatory Strategy formulation field is empty."
        [nodeSubject strategy, valueSubject "field" field]
    DuplicateStrategyPrimitiveReference strategy role identifier ->
      semantic
        "o2i.semantics.formulation-reference-duplicate"
        "A Strategy formulation repeats a Primitive reference."
        [ nodeSubject strategy
        , valueSubject "strategy-role" role
        , nodeSubject identifier
        ]
    InvalidStrategyPrimitiveReference strategy role identifier primitive ->
      semantic
        "o2i.semantics.formulation-reference-invalid"
        "A Strategy formulation reference has the wrong identity or owner."
        [ nodeSubject strategy
        , valueSubject "strategy-role" role
        , nodeSubject identifier
        , valueSubject "required-primitive" primitive
        ]
    StrategyActionWithoutKeyResult strategy action ->
      semantic
        "o2i.semantics.strategy-action-unsubstantiated"
        "A formulated Strategy Action contributes to no listed Key Result."
        [nodeSubject strategy, nodeSubject action]
    MissingStrategyCoherence strategy from relation to ->
      semantic
        "o2i.semantics.strategy-coherence-missing"
        "A required Strategy coherence relation is absent."
        [ nodeSubject strategy
        , nodeSubject from
        , relationSubject relation
        , nodeSubject to
        ]
  where
    semantic = coreSpec SemanticsStage

-- | Total diagnostic mapping for every traceability defect.
traceabilityDefectSpec :: TraceabilityError -> DiagnosticSpec
traceabilityDefectSpec defect =
  case defect of
    NoIntervention ->
      trace
        "o2i.traceability.intervention-missing"
        "The model contains no Intervention."
        []
    InterventionWithoutNeed intervention ->
      trace
        "o2i.traceability.intervention-need-missing"
        "An Intervention addresses no Need."
        [nodeSubject intervention]
    MissingMacroEvidence from relation to ->
      trace
        "o2i.traceability.macro-evidence-missing"
        "A context relation lacks its required Primitive evidence."
        [nodeSubject from, relationSubject relation, nodeSubject to]
    MissingEffectTrace intervention need ->
      trace
        "o2i.traceability.effect-trace-missing"
        "An Intervention and addressed Need have no complete effect trace."
        [nodeSubject intervention, nodeSubject need]
  where
    trace = coreSpec TraceabilityStage

-- | Total diagnostic mapping for every evidence-readiness defect.
readinessDefectSpec :: EvidenceReadinessError -> DiagnosticSpec
readinessDefectSpec defect =
  case defect of
    UnknownKPIDefinition identifier ->
      readinessNode "kpi-definition-unknown" identifier
    DuplicateKPIDefinition identifier count ->
      readinessCount "kpi-definition-duplicate" identifier count
    ConflictingKPIDefinition identifier count ->
      readinessCount "kpi-definition-conflicting" identifier count
    MissingKPIDefinition identifier ->
      readiness "kpi-definition-missing" [nodeSubject (unNodeId identifier)]
    InvalidKPIValueDomain identifier domain ->
      readiness
        "kpi-domain-invalid"
        [nodeSubject identifier, valueSubject "domain" domain]
    EmptyKPIUnit identifier -> readinessNode "kpi-unit-empty" identifier
    EmptyKPIMeasurementMethod identifier ->
      readinessNode "kpi-method-empty" identifier
    EmptyKPIInterpretation identifier ->
      readinessNode "kpi-interpretation-empty" identifier
    UnknownPlannedInterventionStart identifier ->
      readinessNode "planned-start-unknown" identifier
    DuplicatePlannedInterventionStart identifier count ->
      readinessCount "planned-start-duplicate" identifier count
    MissingPlannedInterventionStart intervention ->
      readiness
        "planned-start-missing"
        [nodeSubject (contextRefId intervention)]
    ReadinessCheckedAtOrAfterPlannedStart intervention ->
      readiness
        "check-not-before-start"
        [nodeSubject (contextRefId intervention)]
    UnknownEvidencePlanTrace trace -> readinessTrace "plan-trace-unknown" trace
    DuplicateEvidencePlan trace count ->
      readinessTraceCount "plan-duplicate" trace count
    MissingEvidencePlan trace -> readinessTrace "plan-missing" trace
    PlanEstablishedAfterCheck trace ->
      readinessTrace "plan-established-after-check" trace
    BaselineObservedAfterCheck trace ->
      readinessTrace "baseline-after-check" trace
    InvalidTargetDueDate trace -> readinessTrace "target-date-invalid" trace
    BaselineKPIMismatch trace expected actual ->
      readinessTraceNodes "baseline-kpi-mismatch" trace expected actual
    BaselineAnchorMismatch trace expected actual ->
      readinessTraceNodes "baseline-anchor-mismatch" trace expected actual
    InvalidEffectCriterion trace ->
      readinessTrace "effect-criterion-invalid" trace
    RelativeEffectCriterionWithZeroBaseline trace ->
      readinessTrace "relative-baseline-zero" trace
    InvalidTargetCriterion trace ->
      readinessTrace "target-criterion-invalid" trace
    BaselineLevelOutsideDomain trace level domain ->
      readinessTraceValues "baseline-domain-invalid" trace level domain
    EffectCriterionOutsideDomain trace level domain ->
      readinessTraceValues "effect-domain-invalid" trace level domain
    TargetCriterionOutsideDomain trace level domain ->
      readinessTraceValues "target-domain-invalid" trace level domain
    EmptyPlanSource trace -> readinessTrace "plan-source-empty" trace
    EmptyBaselineSource trace -> readinessTrace "baseline-source-empty" trace
  where
    readiness suffix subjects =
      coreSpec
        ReadinessStage
        ("o2i.readiness." <> suffix)
        "Evidence readiness validation failed."
        subjects
    readinessNode suffix identifier = readiness suffix [nodeSubject identifier]
    readinessCount suffix identifier count =
      readiness suffix [nodeSubject identifier, countSubject count]
    readinessTrace suffix trace = readiness suffix [traceSubject trace]
    readinessTraceCount suffix trace count =
      readiness suffix [traceSubject trace, countSubject count]
    readinessTraceNodes suffix trace left right =
      readiness suffix [traceSubject trace, nodeSubject left, nodeSubject right]
    readinessTraceValues suffix trace value domain =
      readiness
        suffix
        [ traceSubject trace
        , valueSubject "level" value
        , valueSubject "domain" domain
        ]

-- | Total diagnostic mapping for every ex-post evidence defect.
evidenceDefectSpec :: EvidenceError -> DiagnosticSpec
evidenceDefectSpec defect =
  case defect of
    UnknownActualInterventionStart identifier ->
      evidenceNode "actual-start-unknown" identifier
    DuplicateActualInterventionStart identifier count ->
      evidenceCount "actual-start-duplicate" identifier count
    MissingActualInterventionStart intervention ->
      evidence "actual-start-missing" [nodeSubject (contextRefId intervention)]
    ActualInterventionStartAtOrBeforeReadiness intervention ->
      evidence
        "actual-start-before-readiness"
        [nodeSubject (contextRefId intervention)]
    ActualInterventionStartAtOrAfterAssessment intervention ->
      evidence
        "actual-start-after-assessment"
        [nodeSubject (contextRefId intervention)]
    UnknownFollowUpTrace trace -> evidenceTrace "follow-up-trace-unknown" trace
    DuplicateFollowUpObservation trace timestamp count ->
      evidence
        "follow-up-duplicate"
        [ traceSubject trace
        , valueSubject "timestamp" timestamp
        , countSubject count
        ]
    MissingFollowUpObservation trace -> evidenceTrace "follow-up-missing" trace
    FollowUpKPIMismatch trace expected actual ->
      evidenceTraceNodes "follow-up-kpi-mismatch" trace expected actual
    FollowUpAnchorMismatch trace expected actual ->
      evidenceTraceNodes "follow-up-anchor-mismatch" trace expected actual
    FollowUpLevelOutsideDomain trace level domain ->
      evidence
        "follow-up-domain-invalid"
        [ traceSubject trace
        , valueSubject "level" level
        , valueSubject "domain" domain
        ]
    FollowUpObservedAtOrBeforeActualStart trace ->
      evidenceTrace "follow-up-before-start" trace
    FollowUpObservedAfterAssessment trace ->
      evidenceTrace "follow-up-after-assessment" trace
    EmptyFollowUpSource trace -> evidenceTrace "follow-up-source-empty" trace
  where
    evidence suffix subjects =
      coreSpec
        EvidenceStage
        ("o2i.evidence." <> suffix)
        "Effect evidence validation failed."
        subjects
    evidenceNode suffix identifier = evidence suffix [nodeSubject identifier]
    evidenceCount suffix identifier count =
      evidence suffix [nodeSubject identifier, countSubject count]
    evidenceTrace suffix trace = evidence suffix [traceSubject trace]
    evidenceTraceNodes suffix trace left right =
      evidence suffix [traceSubject trace, nodeSubject left, nodeSubject right]

coreSpec ::
     InspectionStage -> Text -> Text -> [DiagnosticSubject] -> DiagnosticSpec
coreSpec stage code message subjects =
  DiagnosticSpec
    { specCode = DiagnosticCode code
    , specStage = stage
    , specSeverity = ErrorSeverity
    , specDisposition = ModelFinding
    , specMessage = message
    , specSubjects = subjects
    , specData = Map.empty
    }

nodeSubject :: RawNodeId -> DiagnosticSubject
nodeSubject identifier = DiagnosticSubject "node" (rawNodeIdText identifier)

ownerSubject :: RawNodeId -> DiagnosticSubject
ownerSubject identifier = DiagnosticSubject "owner" (rawNodeIdText identifier)

edgeSubject :: RawEdge -> DiagnosticSubject
edgeSubject edge =
  DiagnosticSubject
    "edge"
    (Text.intercalate
       ":"
       [ rawNodeIdText (rawEdgeFrom edge)
       , relationNameText (rawEdgeRelation edge)
       , rawNodeIdText (rawEdgeTo edge)
       ])

relationSubject :: RelationName -> DiagnosticSubject
relationSubject relation =
  DiagnosticSubject "relation" (relationNameText relation)

traceSubject :: EffectTraceId -> DiagnosticSubject
traceSubject trace = DiagnosticSubject "effect-trace" (Text.pack (show trace))

countSubject :: Int -> DiagnosticSubject
countSubject count = DiagnosticSubject "count" (Text.pack (show count))

valueSubject :: Show value => Text -> value -> DiagnosticSubject
valueSubject kind value = DiagnosticSubject kind (Text.pack (show value))
