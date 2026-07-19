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
  , diagnosticWithSupplementalSources
  , normalizeDiagnostics
  , diagnosticsList
  , rawEdgeSubjectIdentifier
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
import Data.Ratio (denominator, numerator)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.Lazy.Builder as TextBuilder
import qualified Data.Text.Lazy.Builder.Int as TextBuilder
import Data.Time (UTCTime(..), diffTimeToPicoseconds, toModifiedJulianDay)
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
  , diagnosticSupplementalSources :: [SupplementalSource]
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
    { diagnosticId = diagnosticIdentity specification locations []
    , diagnosticCode = specCode specification
    , diagnosticStage = specStage specification
    , diagnosticSeverity = specSeverity specification
    , diagnosticDisposition = specDisposition specification
    , diagnosticMessage = specMessage specification
    , diagnosticSubjects = specSubjects specification
    , diagnosticLocations = locations
    , diagnosticSupplementalSources = []
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

-- | Attach consumed supplemental sources and refresh diagnostic identity.
diagnosticWithSupplementalSources ::
     [SupplementalSource] -> Diagnostic -> Diagnostic
diagnosticWithSupplementalSources sources diagnostic =
  diagnostic
    { diagnosticId =
        diagnosticIdentityFields
          (diagnosticCode diagnostic)
          (diagnosticStage diagnostic)
          (diagnosticSeverity diagnostic)
          (diagnosticDisposition diagnostic)
          (diagnosticSubjects diagnostic)
          (diagnosticLocations diagnostic)
          sources
          (diagnosticData diagnostic)
    , diagnosticSupplementalSources = sources
    }

-- | Sort diagnostics by stage, code, subject, and source occurrence.
normalizeDiagnostics :: [Diagnostic] -> Diagnostics
normalizeDiagnostics = Diagnostics . sortOn diagnosticSortKey

-- | Read diagnostics in canonical order.
diagnosticsList :: Diagnostics -> [Diagnostic]
diagnosticsList (Diagnostics diagnostics) = diagnostics

diagnosticSortKey :: Diagnostic -> (Int, Text, Text, Text, Text)
diagnosticSortKey diagnostic =
  ( fromEnum (diagnosticStage diagnostic)
  , diagnosticCodeText (diagnosticCode diagnostic)
  , subjectsKey (diagnosticSubjects diagnostic)
  , locationsKey (diagnosticLocations diagnostic)
  , supplementalSourcesKey (diagnosticSupplementalSources diagnostic))

diagnosticIdentity ::
     DiagnosticSpec -> [SourceLocation] -> [SupplementalSource] -> DiagnosticId
diagnosticIdentity specification locations sources =
  diagnosticIdentityFields
    (specCode specification)
    (specStage specification)
    (specSeverity specification)
    (specDisposition specification)
    (specSubjects specification)
    locations
    sources
    (specData specification)

diagnosticIdentityFields ::
     DiagnosticCode
  -> InspectionStage
  -> DiagnosticSeverity
  -> DiagnosticDisposition
  -> [DiagnosticSubject]
  -> [SourceLocation]
  -> [SupplementalSource]
  -> Map Text DiagnosticAtom
  -> DiagnosticId
diagnosticIdentityFields code stage severity disposition subjects locations sources dataFields =
  DiagnosticId
    (canonicalSequence
       [ "o2i-diagnostic-v1"
       , diagnosticCodeText code
       , inspectionStageText stage
       , diagnosticSeverityText severity
       , diagnosticDispositionText disposition
       , subjectsKey subjects
       , locationsKey locations
       , supplementalSourcesKey sources
       , diagnosticDataKey dataFields
       ])

inspectionStageText :: InspectionStage -> Text
inspectionStageText stage =
  case stage of
    DecodeStage -> "decode"
    ViewScopeStage -> "view-scope"
    ProfileStage -> "profile"
    StructureStage -> "structure"
    SemanticsStage -> "semantics"
    TraceabilityStage -> "traceability"
    ReadinessStage -> "readiness"
    EvidenceStage -> "evidence"

diagnosticSeverityText :: DiagnosticSeverity -> Text
diagnosticSeverityText severity =
  case severity of
    DebugSeverity -> "debug"
    InfoSeverity -> "info"
    WarningSeverity -> "warning"
    ErrorSeverity -> "error"

diagnosticDispositionText :: DiagnosticDisposition -> Text
diagnosticDispositionText disposition =
  case disposition of
    ModelFinding -> "model-finding"
    ProcessFailure -> "process-failure"

diagnosticDataKey :: Map Text DiagnosticAtom -> Text
diagnosticDataKey = canonicalList diagnosticDataEntryKey . Map.toAscList

diagnosticDataEntryKey :: (Text, DiagnosticAtom) -> Text
diagnosticDataEntryKey (key, value) =
  canonicalValue "diagnostic-data" [key, diagnosticAtomKey value]

diagnosticAtomKey :: DiagnosticAtom -> Text
diagnosticAtomKey atom =
  case atom of
    DiagnosticText value -> canonicalValue "text" [value]
    DiagnosticInteger value -> canonicalValue "integer" [decimalText value]
    DiagnosticBoolean value ->
      canonicalValue
        "boolean"
        [ if value
            then "true"
            else "false"
        ]

subjectsKey :: [DiagnosticSubject] -> Text
subjectsKey = canonicalList subjectKey

subjectKey :: DiagnosticSubject -> Text
subjectKey subject =
  canonicalValue "subject" [subjectKind subject, subjectIdentifier subject]

locationsKey :: [SourceLocation] -> Text
locationsKey = canonicalList locationKey

locationKey :: SourceLocation -> Text
locationKey location =
  canonicalValue
    "location"
    [ sourceDisplayLabel source
    , sourceInputKindKey (sourceInputKind source)
    , sourceHashText (sourceSha256 source)
    , canonicalList pathKey (NonEmpty.toList (locationPath location))
    , targetKey (locationTarget location)
    , canonicalMaybe spanKey (locationSpan location)
    ]
  where
    source = locationSource location

supplementalSourcesKey :: [SupplementalSource] -> Text
supplementalSourcesKey = canonicalList supplementalSourceKey

supplementalSourceKey :: SupplementalSource -> Text
supplementalSourceKey supplemental =
  canonicalValue
    "supplemental-source"
    [ supplementalInputKindKey (supplementalInputKind supplemental)
    , sourceIdentityKey (supplementalSourceIdentity supplemental)
    ]

supplementalInputKindKey :: SupplementalInputKind -> Text
supplementalInputKindKey kind =
  case kind of
    StrategySupplement -> "strategy"
    ReadinessSupplement -> "readiness"
    EvidenceSupplement -> "evidence"

sourceIdentityKey :: SourceIdentity -> Text
sourceIdentityKey source =
  canonicalValue
    "source"
    [ sourceDisplayLabel source
    , sourceInputKindKey (sourceInputKind source)
    , sourceHashText (sourceSha256 source)
    ]

sourceInputKindKey :: SourceInputKind -> Text
sourceInputKindKey kind =
  case kind of
    FileSource -> "file"
    StandardInputSource -> "stdin"

pathKey :: PathStep -> Text
pathKey step =
  canonicalValue
    "path-step"
    [qNameKey (pathStepName step), decimalText (pathStepOrdinal step)]

qNameKey :: ExpandedQName -> Text
qNameKey name =
  canonicalValue
    "expanded-qname"
    [canonicalMaybe id (qNameNamespace name), qNameLocalName name]

targetKey :: LocationTarget -> Text
targetKey target =
  case target of
    ElementTarget -> "element"
    AttributeTarget name -> canonicalValue "attribute" [qNameKey name]
    PropertyTarget key -> canonicalValue "property" [key]
    TextFieldTarget name -> canonicalValue "text" [qNameKey name]

spanKey :: SourceSpan -> Text
spanKey sourceSpan =
  canonicalValue
    "span"
    [ decimalText (spanStartLine sourceSpan)
    , decimalText (spanStartColumn sourceSpan)
    , decimalText (spanEndLine sourceSpan)
    , decimalText (spanEndColumn sourceSpan)
    ]

canonicalValue :: Text -> [Text] -> Text
canonicalValue constructor fields = canonicalSequence (constructor : fields)

canonicalList :: (value -> Text) -> [value] -> Text
canonicalList encode = canonicalSequence . map encode

canonicalMaybe :: (value -> Text) -> Maybe value -> Text
canonicalMaybe encode optional =
  case optional of
    Nothing -> canonicalValue "none" []
    Just value -> canonicalValue "some" [encode value]

canonicalSequence :: [Text] -> Text
canonicalSequence values =
  decimalText (length values) <> ";" <> Text.concat (map canonicalText values)

canonicalText :: Text -> Text
canonicalText value = decimalText (Text.length value) <> ":" <> value

decimalText :: Integral number => number -> Text
decimalText = LazyText.toStrict . TextBuilder.toLazyText . TextBuilder.decimal

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
        , contextSubject "context" context
        , primitiveSubject "primitive" primitive
        ]
    InvalidStructuringContext identifier context structuring ->
      coreSpec
        StructureStage
        "o2i.structure.structuring-context-invalid"
        "A Structuring element has no role in its owning Context."
        [ nodeSubject identifier
        , contextSubject "context" context
        , structuringSubject "structuring" structuring
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
        , nodeKindSubject "source-kind" fromKind
        , nodeKindSubject "target-kind" toKind
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
    EthosWithoutPrinciple ethos ->
      semantic
        "o2i.semantics.ethos-principle-missing"
        "An Ethos has no Principle."
        [nodeSubject ethos]
    MissionWithoutDriver mission ->
      semantic
        "o2i.semantics.mission-driver-missing"
        "A Mission has no Driver."
        [nodeSubject mission]
    MissionWithoutEthosGuidance mission ->
      semantic
        "o2i.semantics.mission-ethos-guidance-missing"
        "No Ethos Principle guides a Driver owned by the Mission."
        [nodeSubject mission]
    VisionWithoutObjective vision ->
      semantic
        "o2i.semantics.vision-objective-missing"
        "A Vision has no Objective."
        [nodeSubject vision]
    VisionWithoutMissionGrounding vision ->
      semantic
        "o2i.semantics.vision-mission-grounding-missing"
        "No Mission Driver grounds an Objective owned by the Vision."
        [nodeSubject vision]
    VisionWithoutEthosGuidance vision ->
      semantic
        "o2i.semantics.vision-ethos-guidance-missing"
        "No Ethos Principle guides an Objective owned by the Vision."
        [nodeSubject vision]
    StrategyIntentWithoutVisionOrientation strategy intent ->
      semantic
        "o2i.semantics.strategy-vision-orientation-missing"
        "No Vision Objective orients the Strategy formulation's intent."
        [ nodeSubject strategy
        , DiagnosticSubject "intent" (rawNodeIdText intent)
        ]
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
    InterventionWithoutAction intervention ->
      semantic
        "o2i.semantics.intervention-action-missing"
        "An Intervention has no Action."
        [nodeSubject intervention]
    InterventionWithoutKeyResult intervention ->
      semantic
        "o2i.semantics.intervention-key-result-missing"
        "An Intervention has no Key Result."
        [nodeSubject intervention]
    InterventionWithoutActionContribution intervention ->
      semantic
        "o2i.semantics.intervention-action-contribution-missing"
        "No owned Intervention Action contributes to an owned Key Result."
        [nodeSubject intervention]
    MeasureWithoutPerformanceDimension measure ->
      semantic
        "o2i.semantics.measure-performance-dimension-missing"
        "A Measure has no measurement PerformanceDimension."
        [nodeSubject measure]
    MeasureWithoutKPI measure ->
      semantic
        "o2i.semantics.measure-kpi-missing"
        "A Measure has no KPI."
        [nodeSubject measure]
    MeasureWithoutKPIDimensionMembership measure ->
      semantic
        "o2i.semantics.measure-kpi-membership-missing"
        "No owned measurement PerformanceDimension contains an owned KPI."
        [nodeSubject measure]
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
        [nodeSubject identifier, nodeKindSubject "node-kind" kind]
    EmptyStrategyText strategy field ->
      semantic
        "o2i.semantics.formulation-text-empty"
        "A mandatory Strategy formulation field is empty."
        [nodeSubject strategy, strategyTextFieldSubject "field" field]
    DuplicateStrategyPrimitiveReference strategy role identifier ->
      semantic
        "o2i.semantics.formulation-reference-duplicate"
        "A Strategy formulation repeats a Primitive reference."
        [ nodeSubject strategy
        , strategyRoleSubject "strategy-role" role
        , nodeSubject identifier
        ]
    InvalidStrategyPrimitiveReference strategy role identifier primitive ->
      semantic
        "o2i.semantics.formulation-reference-invalid"
        "A Strategy formulation reference has the wrong identity or owner."
        [ nodeSubject strategy
        , strategyRoleSubject "strategy-role" role
        , nodeSubject identifier
        , primitiveSubject "required-primitive" primitive
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
        [nodeSubject identifier, valueDomainSubject "domain" domain]
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
        , levelSubject "level" value
        , valueDomainSubject "domain" domain
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
        , timestampSubject "timestamp" timestamp
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
        , levelSubject "level" level
        , valueDomainSubject "domain" domain
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
edgeSubject edge = DiagnosticSubject "edge" (rawEdgeSubjectIdentifier edge)

-- | Canonical injective identity of one raw directed edge.
rawEdgeSubjectIdentifier :: RawEdge -> Text
rawEdgeSubjectIdentifier edge =
  canonicalValue
    "raw-edge-v1"
    [ rawNodeIdText (rawEdgeFrom edge)
    , relationNameText (rawEdgeRelation edge)
    , rawNodeIdText (rawEdgeTo edge)
    ]

relationSubject :: RelationName -> DiagnosticSubject
relationSubject relation =
  DiagnosticSubject "relation" (relationNameText relation)

traceSubject :: EffectTraceId -> DiagnosticSubject
traceSubject trace = DiagnosticSubject "effect-trace" (effectTraceIdText trace)

countSubject :: Int -> DiagnosticSubject
countSubject count = DiagnosticSubject "count" (decimalText count)

contextSubject :: Text -> Context -> DiagnosticSubject
contextSubject kind context = DiagnosticSubject kind (contextText context)

contextText :: Context -> Text
contextText context =
  case context of
    Ethos -> "ethos"
    Mission -> "mission"
    Vision -> "vision"
    Strategy -> "strategy"
    Situation -> "situation"
    Need -> "need"
    Intervention -> "intervention"
    Measure -> "measure"

primitiveSubject :: Text -> Primitive -> DiagnosticSubject
primitiveSubject kind primitive =
  DiagnosticSubject kind (primitiveText primitive)

primitiveText :: Primitive -> Text
primitiveText primitive =
  case primitive of
    Principle -> "principle"
    Driver -> "driver"
    Objective -> "objective"
    KeyResult -> "key-result"
    KPI -> "kpi"
    Action -> "action"

structuringSubject :: Text -> Structuring -> DiagnosticSubject
structuringSubject kind structuring =
  DiagnosticSubject kind (structuringText structuring)

structuringText :: Structuring -> Text
structuringText structuring =
  case structuring of
    PerformanceDimension -> "performance-dimension"

nodeKindSubject :: Text -> NodeKindValue -> DiagnosticSubject
nodeKindSubject kind nodeKind = DiagnosticSubject kind (nodeKindText nodeKind)

nodeKindText :: NodeKindValue -> Text
nodeKindText nodeKind =
  case nodeKind of
    ContextNodeKind context -> canonicalValue "context" [contextText context]
    PrimitiveNodeKind context primitive ->
      canonicalValue "primitive" [contextText context, primitiveText primitive]
    StructuringNodeKind context structuring ->
      canonicalValue
        "structuring"
        [contextText context, structuringText structuring]
    AnchorNodeKind anchor ->
      canonicalValue "situation-anchor" [situationAnchorText anchor]

situationAnchorText :: SituationAnchor -> Text
situationAnchorText anchor =
  case anchor of
    BusinessCapability -> "business-capability"
    BusinessProcess -> "business-process"
    BusinessObject -> "business-object"
    BusinessRole -> "business-role"
    ValueStream -> "value-stream"
    RegulatoryConstraint -> "regulatory-constraint"

strategyTextFieldSubject :: Text -> StrategyTextField -> DiagnosticSubject
strategyTextFieldSubject kind field =
  DiagnosticSubject kind (strategyTextFieldText field)

strategyTextFieldText :: StrategyTextField -> Text
strategyTextFieldText field =
  case field of
    ScopeField -> "scope"
    PeriodField -> "period"
    ResponsibilityScopeField -> "responsibility-scope"
    DecisionLevelField -> "decision-level"
    ResponsibilitiesField -> "responsibilities"
    DecisionPathsField -> "decision-paths"
    ImplementationLogicField -> "implementation-logic"
    GuardrailsField -> "guardrails"
    PositioningField -> "positioning"
    TradeOffsField -> "trade-offs"
    FitRationaleField -> "fit-rationale"

strategyRoleSubject :: Text -> StrategyPrimitiveRole -> DiagnosticSubject
strategyRoleSubject kind role = DiagnosticSubject kind (strategyRoleText role)

strategyRoleText :: StrategyPrimitiveRole -> Text
strategyRoleText role =
  case role of
    DiagnosisRole -> "diagnosis"
    IntentRole -> "intent"
    GuidingPolicyRole -> "guiding-policy"
    CoherentActionRole -> "coherent-action"
    StrategicKeyResultRole -> "strategic-key-result"

levelSubject :: Text -> Level -> DiagnosticSubject
levelSubject kind level = DiagnosticSubject kind (levelText level)

levelText :: Level -> Text
levelText level = rationalText (levelValue level)

rationalText :: Rational -> Text
rationalText value =
  canonicalValue
    "rational"
    [decimalText (numerator value), decimalText (denominator value)]

valueDomainSubject :: Text -> ValueDomain -> DiagnosticSubject
valueDomainSubject kind domain = DiagnosticSubject kind (valueDomainText domain)

valueDomainText :: ValueDomain -> Text
valueDomainText domain =
  case domain of
    UnboundedDomain -> canonicalValue "unbounded" []
    LowerBoundedDomain lower -> canonicalValue "lower-bounded" [levelText lower]
    UpperBoundedDomain upper -> canonicalValue "upper-bounded" [levelText upper]
    BoundedDomain lower upper ->
      canonicalValue "bounded" [levelText lower, levelText upper]

timestampSubject :: Text -> UTCTime -> DiagnosticSubject
timestampSubject kind timestamp =
  DiagnosticSubject kind (timestampText timestamp)

timestampText :: UTCTime -> Text
timestampText (UTCTime day dayTime) =
  canonicalValue
    "utc-time"
    [ decimalText (toModifiedJulianDay day)
    , decimalText (diffTimeToPicoseconds dayTime)
    ]
