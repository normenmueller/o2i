{-# LANGUAGE OverloadedStrings #-}

-- | Internal constructors and deterministic serialization for reports.
module O2I.Inspection.Report.Internal
  ( StageState(..)
  , BlockReason(..)
  , StageReport(..)
  , StageReports(..)
  , InspectionResult(..)
  , NativeBindingFailure(..)
  , NativeAdapterBinding(..)
  , FailedViewResolution(..)
  , ResolvedViewResolution(..)
  , ViewResolution(..)
  , RejectedO2IProfile(..)
  , O2IProfileResolution(..)
  , ScopeFailure(..)
  , ResolvedScope(..)
  , ScopeResolution(..)
  , InspectionRequestInfo(..)
  , InspectionSemanticAssessment(..)
  , InspectionReport(..)
  , CommandErrorClassification(..)
  , InvocationDefect(..)
  , CommandError(..)
  , reportRequestInfo
  , reportNativeBinding
  , reportViewResolution
  , reportProfileResolution
  , reportScopeResolution
  , reportClosedScopeProvenance
  , reportSupplementalSources
  , reportSemanticAssessment
  , reportMaturity
  , reportMaturityText
  , semanticCollectiveStrategyRealizations
  , reportStageReports
  , reportDiagnostics
  , reportResult
  , reportExitCode
  , commandErrorExitCode
  , stageReportsList
  , mkStageReports
  , renderInspectionReportJSON
  , renderCommandErrorJSON
  ) where

import Data.Aeson (Value, (.=), encode, object, toJSON)
import Data.Aeson.Types (Pair)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Maybe (catMaybes)
import Data.Text (Text)
import O2I
  ( CollectiveStrategyRealization
  , Maturity(..)
  , ValidatedCollectiveStrategyRealizations
  , collectiveStrategyRealizations
  )
import O2I.Inspection.Adapter
import O2I.Inspection.Cardinality
import O2I.Inspection.Diagnostic.Internal
import O2I.Inspection.Profile
import O2I.Inspection.Provenance
import O2I.Inspection.Scope

-- | Why a later stage did not run.
data BlockReason
  = BlockedByFailure InspectionStage
  | BlockedByUnavailable InspectionStage
  deriving (Eq, Show)

-- | Total state of one inspection stage.
data StageState
  = StagePassed
  | StageFailed
  | StageUnavailable
  | StageNotRun BlockReason
  deriving (Eq, Show)

-- | One canonical stage record and its diagnostic identities.
data StageReport = StageReport
  { reportedStage :: InspectionStage
  , reportedState :: StageState
  , reportedDiagnosticIds :: [DiagnosticId]
  } deriving (Eq, Show)

-- | Exactly eight stage records in normative order.
data StageReports = StageReports
  { decodeStageReport :: StageReport
  , viewScopeStageReport :: StageReport
  , profileStageReport :: StageReport
  , structureStageReport :: StageReport
  , semanticsStageReport :: StageReport
  , traceabilityStageReport :: StageReport
  , readinessStageReport :: StageReport
  , evidenceStageReport :: StageReport
  } deriving (Eq, Show)

-- | Result derived exclusively from all eight stage states.
data InspectionResult
  = InspectionPassed
  | InspectionPartial
  | InspectionFailed
  deriving (Eq, Ord, Show)

-- | Native-format failure retaining exactly the safe observations.
data NativeBindingFailure
  = NativeBindingUnavailable
      (DecodeUnavailableObservation SourceLocation)
      (NonEmpty DiagnosticId)
  | NativeBindingRejected
      (RejectedNativeBinding SourceLocation)
      (NonEmpty DiagnosticId)
  deriving (Eq, Show)

-- | Native adapter binding observable in every report state.
data NativeAdapterBinding
  = NativeBindingFailed NativeBindingFailure
  | NativeBindingResolved ResolvedNativeBinding
  deriving (Eq, Show)

-- | Failed exact View resolution and all stable matching candidates.
data FailedViewResolution = FailedViewResolution
  { failedViewObservation :: ObservedViewResolution SourceLocation
  , failedViewDiagnosticIds :: NonEmpty DiagnosticId
  } deriving (Eq, Show)

-- | Successful exact View resolution.
newtype ResolvedViewResolution = ResolvedViewResolution
  { resolvedView :: ResolvedView SourceLocation
  } deriving (Eq, Show)

-- | View resolution observable at one report state.
data ViewResolution
  = ViewUnavailable
  | ViewRejected FailedViewResolution
  | ViewResolved ResolvedViewResolution
  deriving (Eq, Show)

-- | Rejected root profile and its diagnostic identities.
data RejectedO2IProfile = RejectedO2IProfile
  { rejectedProfileObservation :: ObservedO2IProfile
  , rejectedProfileDiagnosticIds :: NonEmpty DiagnosticId
  } deriving (Eq, Show)

-- | O2I profile resolution observable at one report state.
data O2IProfileResolution
  = ProfileUnavailable
  | ProfileRejectedResolution RejectedO2IProfile
  | ProfileResolvedResolution ResolvedO2IProfile
  deriving (Eq, Show)

-- | Rejected semantic closure summary.
data ScopeFailure = ScopeFailure
  { rejectedScopeSummary :: ClosedScopeSummary
  , rejectedScopeDiagnosticIds :: NonEmpty DiagnosticId
  } deriving (Eq, Show)

-- | Summary and mandatory provenance of a successfully resolved scope.
data ResolvedScope = ResolvedScope
  { resolvedScopeSummary :: ClosedScopeSummary -- ^ Closure cardinalities.
  , resolvedScopeProvenance :: ClosedScopeProvenance
    -- ^ Complete canonical provenance artifact.
  } deriving (Eq, Show)

-- | Semantic closure state observable in reports.
data ScopeResolution
  = ScopeUnavailable
  | ScopeRejectedResolution ScopeFailure
  | ScopeResolved ResolvedScope
  deriving (Eq, Show)

-- | Common immutable request information retained in every report.
data InspectionRequestInfo = InspectionRequestInfo
  { requestSourceIdentity :: SourceIdentity
  , requestAdapter :: AdapterDescriptor
  , requestedViewSelector :: ViewSelector
  } deriving (Eq, Show)

-- | Semantic result for the complete inspected claim boundary.
data InspectionSemanticAssessment =
  InspectionSemanticAssessment
    Maturity
    (Maybe ValidatedCollectiveStrategyRealizations)

-- | State-indexed inspection report. Constructors are private to Inspection.
data InspectionReport
  = DecodeRejectedReport
      InspectionRequestInfo
      NativeBindingFailure
      StageReports
      Diagnostics
  | ViewRejectedReport
      InspectionRequestInfo
      ResolvedNativeBinding
      FailedViewResolution
      StageReports
      Diagnostics
  | ProfileRejectedReport
      InspectionRequestInfo
      ResolvedNativeBinding
      ResolvedViewResolution
      RejectedO2IProfile
      StageReports
      Diagnostics
  | ScopeRejectedReport
      InspectionRequestInfo
      ResolvedNativeBinding
      ResolvedViewResolution
      ResolvedO2IProfile
      ScopeFailure
      StageReports
      Diagnostics
  | PipelineReport
      InspectionRequestInfo
      ResolvedNativeBinding
      ResolvedViewResolution
      ResolvedO2IProfile
      ResolvedScope
      [SupplementalSource]
      (Maybe InspectionSemanticAssessment)
      StageReports
      Diagnostics

-- | Stable command-error classification.
data CommandErrorClassification
  = InvocationError
  | InputIOError
  | InternalError
  deriving (Eq, Ord, Show)

-- | Closed invocation failures shared with a thin CLI.
data InvocationDefect =
  InvalidInvocation
  deriving (Eq, Ord, Show)

-- | Process failures that are not model-inspection reports.
data CommandError
  = InvocationCommandError InvocationDefect Text
  | InputCommandError Text Text
  | StructureInternalCommandError Text
  deriving (Eq, Show)

-- | Read common request information.
reportRequestInfo :: InspectionReport -> InspectionRequestInfo
reportRequestInfo report =
  case report of
    DecodeRejectedReport request _ _ _ -> request
    ViewRejectedReport request _ _ _ _ -> request
    ProfileRejectedReport request _ _ _ _ _ -> request
    ScopeRejectedReport request _ _ _ _ _ _ -> request
    PipelineReport request _ _ _ _ _ _ _ _ -> request

-- | Read native binding state without inspecting a report constructor.
reportNativeBinding :: InspectionReport -> NativeAdapterBinding
reportNativeBinding report =
  case report of
    DecodeRejectedReport _ failure _ _ -> NativeBindingFailed failure
    ViewRejectedReport _ binding _ _ _ -> NativeBindingResolved binding
    ProfileRejectedReport _ binding _ _ _ _ -> NativeBindingResolved binding
    ScopeRejectedReport _ binding _ _ _ _ _ -> NativeBindingResolved binding
    PipelineReport _ binding _ _ _ _ _ _ _ -> NativeBindingResolved binding

-- | Read View resolution without duplicating the requested selector.
reportViewResolution :: InspectionReport -> ViewResolution
reportViewResolution report =
  case report of
    DecodeRejectedReport {} -> ViewUnavailable
    ViewRejectedReport _ _ failure _ _ -> ViewRejected failure
    ProfileRejectedReport _ _ resolution _ _ _ -> ViewResolved resolution
    ScopeRejectedReport _ _ resolution _ _ _ _ -> ViewResolved resolution
    PipelineReport _ _ resolution _ _ _ _ _ _ -> ViewResolved resolution

-- | Read root-profile resolution allowed by the report state.
reportProfileResolution :: InspectionReport -> O2IProfileResolution
reportProfileResolution report =
  case report of
    DecodeRejectedReport {} -> ProfileUnavailable
    ViewRejectedReport {} -> ProfileUnavailable
    ProfileRejectedReport _ _ _ rejected _ _ ->
      ProfileRejectedResolution rejected
    ScopeRejectedReport _ _ _ resolved _ _ _ ->
      ProfileResolvedResolution resolved
    PipelineReport _ _ _ resolved _ _ _ _ _ ->
      ProfileResolvedResolution resolved

-- | Read semantic-scope resolution allowed by the report state.
reportScopeResolution :: InspectionReport -> ScopeResolution
reportScopeResolution report =
  case report of
    DecodeRejectedReport {} -> ScopeUnavailable
    ViewRejectedReport {} -> ScopeUnavailable
    ProfileRejectedReport {} -> ScopeUnavailable
    ScopeRejectedReport _ _ _ _ failure _ _ -> ScopeRejectedResolution failure
    PipelineReport _ _ _ _ scope _ _ _ _ -> ScopeResolved scope

-- | Read the mandatory artifact of a successfully resolved scope.
reportClosedScopeProvenance :: InspectionReport -> Maybe ClosedScopeProvenance
reportClosedScopeProvenance report =
  case reportScopeResolution report of
    ScopeResolved scope -> Just (resolvedScopeProvenance scope)
    ScopeUnavailable -> Nothing
    ScopeRejectedResolution _ -> Nothing

-- | Read supplemental source identities actually consumed by validation.
reportSupplementalSources :: InspectionReport -> [SupplementalSource]
reportSupplementalSources report =
  case report of
    DecodeRejectedReport {} -> []
    ViewRejectedReport {} -> []
    ProfileRejectedReport {} -> []
    ScopeRejectedReport {} -> []
    PipelineReport _ _ _ _ _ sources _ _ _ -> sources

-- | Read the complete semantic assessment when Semantics was assessed.
reportSemanticAssessment ::
     InspectionReport -> Maybe InspectionSemanticAssessment
reportSemanticAssessment report =
  case report of
    PipelineReport _ _ _ _ _ _ assessment _ _ -> assessment
    DecodeRejectedReport {} -> Nothing
    ViewRejectedReport {} -> Nothing
    ProfileRejectedReport {} -> Nothing
    ScopeRejectedReport {} -> Nothing

-- | Read exact maturity after Semantics assessment.
reportMaturity :: InspectionReport -> Maybe Maturity
reportMaturity = fmap semanticAssessmentMaturity . reportSemanticAssessment

-- | Read the stable external text of exact post-Semantics maturity.
reportMaturityText :: InspectionReport -> Maybe Text
reportMaturityText = fmap maturityText . reportMaturity

-- | Enumerate retained validated collective realizations.
semanticCollectiveStrategyRealizations ::
     InspectionSemanticAssessment -> [CollectiveStrategyRealization]
semanticCollectiveStrategyRealizations (InspectionSemanticAssessment _ assessment) =
  maybe [] collectiveStrategyRealizations assessment

semanticAssessmentMaturity :: InspectionSemanticAssessment -> Maturity
semanticAssessmentMaturity (InspectionSemanticAssessment maturity _) = maturity

-- | Read the exact eight stage reports.
reportStageReports :: InspectionReport -> StageReports
reportStageReports report =
  case report of
    DecodeRejectedReport _ _ stages _ -> stages
    ViewRejectedReport _ _ _ stages _ -> stages
    ProfileRejectedReport _ _ _ _ stages _ -> stages
    ScopeRejectedReport _ _ _ _ _ stages _ -> stages
    PipelineReport _ _ _ _ _ _ _ stages _ -> stages

-- | Read all diagnostics in deterministic order.
reportDiagnostics :: InspectionReport -> Diagnostics
reportDiagnostics report =
  case report of
    DecodeRejectedReport _ _ _ diagnostics -> diagnostics
    ViewRejectedReport _ _ _ _ diagnostics -> diagnostics
    ProfileRejectedReport _ _ _ _ _ diagnostics -> diagnostics
    ScopeRejectedReport _ _ _ _ _ _ diagnostics -> diagnostics
    PipelineReport _ _ _ _ _ _ _ _ diagnostics -> diagnostics

-- | Derive the result solely from stage states.
reportResult :: InspectionReport -> InspectionResult
reportResult = stageResult . stageReportsList . reportStageReports

-- | Stable process exit status for a completed model inspection.
reportExitCode :: InspectionReport -> Int
reportExitCode report =
  case reportResult report of
    InspectionPassed -> 0
    InspectionFailed -> 1
    InspectionPartial -> 3

-- | Every invocation, input-I/O, or internal command error exits with 2.
commandErrorExitCode :: CommandError -> Int
commandErrorExitCode commandError =
  case commandError of
    InvocationCommandError {} -> 2
    InputCommandError {} -> 2
    StructureInternalCommandError {} -> 2

-- | Read stages in their sole canonical order.
stageReportsList :: StageReports -> [StageReport]
stageReportsList reports =
  [ decodeStageReport reports
  , viewScopeStageReport reports
  , profileStageReport reports
  , structureStageReport reports
  , semanticsStageReport reports
  , traceabilityStageReport reports
  , readinessStageReport reports
  , evidenceStageReport reports
  ]

-- | Construct the exact eight-stage record after checking stage identities.
mkStageReports ::
     StageReport
  -> StageReport
  -> StageReport
  -> StageReport
  -> StageReport
  -> StageReport
  -> StageReport
  -> StageReport
  -> Maybe StageReports
mkStageReports decode view profile structure semantics trace readiness evidence
  | map reportedStage supplied == [minBound .. maxBound] =
    Just
      StageReports
        { decodeStageReport = decode
        , viewScopeStageReport = view
        , profileStageReport = profile
        , structureStageReport = structure
        , semanticsStageReport = semantics
        , traceabilityStageReport = trace
        , readinessStageReport = readiness
        , evidenceStageReport = evidence
        }
  | otherwise = Nothing
  where
    supplied =
      [decode, view, profile, structure, semantics, trace, readiness, evidence]

-- | Encode one deterministic, schema-versioned inspection report.
renderInspectionReportJSON :: InspectionReport -> LazyByteString.ByteString
renderInspectionReportJSON = encode . inspectionReportValue

-- | Encode one deterministic, schema-versioned command error.
renderCommandErrorJSON :: CommandError -> LazyByteString.ByteString
renderCommandErrorJSON commandError =
  encode
    (object
       [ "schema" .= ("o2i.command-error/v1" :: Text)
       , "tool" .= toolValue
       , "error" .= commandErrorValue commandError
       ])

stageResult :: [StageReport] -> InspectionResult
stageResult stages
  | any ((== StageFailed) . reportedState) stages = InspectionFailed
  | any ((== StageUnavailable) . reportedState) stages = InspectionPartial
  | otherwise = InspectionPassed

inspectionReportValue :: InspectionReport -> Value
inspectionReportValue report =
  object
    ([ "schema" .= ("o2i.inspection.report/v1" :: Text)
     , "tool" .= toolValue
     , "inspectionState" .= inspectionStateText report
     , "request" .= requestValue (reportRequestInfo report)
     , "nativeBinding" .= nativeBindingValue (reportNativeBinding report)
     , "supplementalSources"
         .= map supplementalSourceValue (reportSupplementalSources report)
     ]
       ++ catMaybes
            [ viewResolutionField (reportViewResolution report)
            , profileResolutionField (reportProfileResolution report)
            , scopeResolutionField (reportScopeResolution report)
            , maturityField (reportMaturity report)
            ]
       ++ [ "result" .= inspectionResultText (reportResult report)
          , "stages"
              .= map
                   stageReportValue
                   (stageReportsList (reportStageReports report))
          , "diagnostics"
              .= map
                   diagnosticValue
                   (diagnosticsList (reportDiagnostics report))
          ])

toolValue :: Value
toolValue = object ["name" .= ("o2i" :: Text), "reportVersion" .= ("1" :: Text)]

maturityField :: Maybe Maturity -> Maybe Pair
maturityField = fmap ("maturity" .=) . fmap maturityText

maturityText :: Maturity -> Text
maturityText maturity =
  case maturity of
    Skeleton -> "skeleton"
    Draft -> "draft"
    SemanticallyValid -> "semantically-valid"

requestValue :: InspectionRequestInfo -> Value
requestValue request =
  object
    [ "source" .= sourceIdentityValue (requestSourceIdentity request)
    , "adapter" .= adapterValue (requestAdapter request)
    , "viewSelector" .= viewSelectorValue (requestedViewSelector request)
    ]

sourceIdentityValue :: SourceIdentity -> Value
sourceIdentityValue source =
  object
    [ "label" .= sourceDisplayLabel source
    , "inputKind" .= sourceInputKindText (sourceInputKind source)
    , "sha256" .= sourceHashText (sourceSha256 source)
    ]

adapterValue :: AdapterDescriptor -> Value
adapterValue descriptor =
  object
    [ "id" .= adapterIdentifier descriptor
    , "name" .= adapterName descriptor
    , "version" .= adapterVersion descriptor
    ]

viewSelectorValue :: ViewSelector -> Value
viewSelectorValue selector =
  case selector of
    ViewByName name -> object ["kind" .= ("name" :: Text), "value" .= name]
    ViewById identifier ->
      object ["kind" .= ("id" :: Text), "value" .= identifier]

nativeBindingValue :: NativeAdapterBinding -> Value
nativeBindingValue binding =
  case binding of
    NativeBindingFailed failure ->
      object
        ["state" .= ("failed" :: Text), "failure" .= nativeFailureValue failure]
    NativeBindingResolved resolved ->
      object
        [ "state" .= ("resolved" :: Text)
        , "rootQName" .= qNameValue (nativeRootQName resolved)
        , "nativeVersion" .= nativeVersionText (nativeVersion resolved)
        ]

nativeFailureValue :: NativeBindingFailure -> Value
nativeFailureValue failure =
  case failure of
    NativeBindingUnavailable observation ids ->
      object
        [ "kind" .= ("unavailable" :: Text)
        , "encoding"
            .= encodingObservationValue (unavailableEncoding observation)
        , "diagnosticIds" .= map diagnosticIdText (NonEmpty.toList ids)
        ]
    NativeBindingRejected rejected ids ->
      object
        [ "kind" .= ("rejected" :: Text)
        , "encoding" .= ("utf-8" :: Text)
        , "rootQName" .= qNameValue (locatedValue (rejectedRootQName rejected))
        , "nativeVersion" .= fmap locatedValue (rejectedNativeVersion rejected)
        , "diagnosticIds" .= map diagnosticIdText (NonEmpty.toList ids)
        ]

viewResolutionField :: ViewResolution -> Maybe Pair
viewResolutionField resolution =
  case resolution of
    ViewUnavailable -> Nothing
    ViewRejected failure ->
      Just
        ( "viewResolution"
        , object
            [ "state" .= ("rejected" :: Text)
            , "observation" .= observedViewValue (failedViewObservation failure)
            , "diagnosticIds"
                .= map
                     diagnosticIdText
                     (NonEmpty.toList (failedViewDiagnosticIds failure))
            ])
    ViewResolved resolved ->
      Just
        ( "viewResolution"
        , object
            [ "state" .= ("resolved" :: Text)
            , "view" .= resolvedViewValue (resolvedView resolved)
            ])

profileResolutionField :: O2IProfileResolution -> Maybe Pair
profileResolutionField resolution =
  case resolution of
    ProfileUnavailable -> Nothing
    ProfileRejectedResolution rejected ->
      Just
        ( "profileResolution"
        , object
            [ "state" .= ("rejected" :: Text)
            , "observed"
                .= observedProfileValue (rejectedProfileObservation rejected)
            , "diagnosticIds"
                .= map
                     diagnosticIdText
                     (NonEmpty.toList (rejectedProfileDiagnosticIds rejected))
            ])
    ProfileResolvedResolution resolved ->
      Just
        ( "profileResolution"
        , object
            [ "state" .= ("resolved" :: Text)
            , "version" .= profileVersionText (resolvedProfileVersion resolved)
            ])

scopeResolutionField :: ScopeResolution -> Maybe Pair
scopeResolutionField resolution =
  case resolution of
    ScopeUnavailable -> Nothing
    ScopeRejectedResolution failure ->
      Just
        ( "scope"
        , object
            [ "state" .= ("rejected" :: Text)
            , "summary" .= scopeSummaryValue (rejectedScopeSummary failure)
            , "diagnosticIds"
                .= map
                     diagnosticIdText
                     (NonEmpty.toList (rejectedScopeDiagnosticIds failure))
            ])
    ScopeResolved scope ->
      Just
        ( "scope"
        , object
            [ "state" .= ("resolved" :: Text)
            , "summary" .= scopeSummaryValue (resolvedScopeSummary scope)
            , "provenance"
                .= closedScopeProvenanceValue (resolvedScopeProvenance scope)
            ])

stageReportValue :: StageReport -> Value
stageReportValue report =
  object
    ([ "stage" .= inspectionStageText (reportedStage report)
     , "state" .= stageStateText (reportedState report)
     , "diagnosticIds" .= map diagnosticIdText (reportedDiagnosticIds report)
     ]
       ++ case reportedState report of
            StageNotRun reason -> ["blockedBy" .= blockReasonValue reason]
            StagePassed -> []
            StageFailed -> []
            StageUnavailable -> [])

blockReasonValue :: BlockReason -> Value
blockReasonValue reason =
  case reason of
    BlockedByFailure stage ->
      object
        ["reason" .= ("failure" :: Text), "stage" .= inspectionStageText stage]
    BlockedByUnavailable stage ->
      object
        [ "reason" .= ("unavailable" :: Text)
        , "stage" .= inspectionStageText stage
        ]

diagnosticValue :: Diagnostic -> Value
diagnosticValue diagnostic =
  object
    [ "id" .= diagnosticIdText (diagnosticId diagnostic)
    , "code" .= diagnosticCodeText (diagnosticCode diagnostic)
    , "stage" .= inspectionStageText (diagnosticStage diagnostic)
    , "severity" .= severityText (diagnosticSeverity diagnostic)
    , "disposition" .= dispositionText (diagnosticDisposition diagnostic)
    , "message" .= diagnosticMessage diagnostic
    , "subjects" .= map subjectValue (diagnosticSubjects diagnostic)
    , "locations" .= map locationValue (diagnosticLocations diagnostic)
    , "supplementalSources"
        .= map
             supplementalSourceValue
             (diagnosticSupplementalSources diagnostic)
    , "data" .= Map.map diagnosticAtomValue (diagnosticData diagnostic)
    ]

supplementalSourceValue :: SupplementalSource -> Value
supplementalSourceValue supplemental =
  object
    [ "kind" .= supplementalInputKindText (supplementalInputKind supplemental)
    , "source" .= sourceIdentityValue (supplementalSourceIdentity supplemental)
    ]

supplementalInputKindText :: SupplementalInputKind -> Text
supplementalInputKindText kind =
  case kind of
    StrategySupplement -> "strategy"
    CollectiveFitSupplement -> "collective-fit"
    ReadinessSupplement -> "readiness"
    EvidenceSupplement -> "evidence"

subjectValue :: DiagnosticSubject -> Value
subjectValue subject =
  object ["kind" .= subjectKind subject, "id" .= subjectIdentifier subject]

locationValue :: SourceLocation -> Value
locationValue location =
  object
    ([ "source" .= sourceIdentityValue (locationSource location)
     , "path" .= map pathStepValue (NonEmpty.toList (locationPath location))
     , "target" .= locationTargetValue (locationTarget location)
     ]
       ++ maybe
            []
            (\sourceSpan -> ["span" .= sourceSpanValue sourceSpan])
            (locationSpan location))

pathStepValue :: PathStep -> Value
pathStepValue step =
  object
    [ "name" .= qNameValue (pathStepName step)
    , "ordinal" .= pathStepOrdinal step
    ]

qNameValue :: ExpandedQName -> Value
qNameValue name =
  object
    ["namespace" .= qNameNamespace name, "localName" .= qNameLocalName name]

locationTargetValue :: LocationTarget -> Value
locationTargetValue target =
  case target of
    ElementTarget -> object ["kind" .= ("element" :: Text)]
    AttributeTarget name ->
      object ["kind" .= ("attribute" :: Text), "name" .= qNameValue name]
    PropertyTarget key -> object ["kind" .= ("property" :: Text), "key" .= key]
    TextFieldTarget name ->
      object ["kind" .= ("text-field" :: Text), "name" .= qNameValue name]

sourceSpanValue :: SourceSpan -> Value
sourceSpanValue sourceSpan =
  object
    [ "startLine" .= spanStartLine sourceSpan
    , "startColumn" .= spanStartColumn sourceSpan
    , "endLine" .= spanEndLine sourceSpan
    , "endColumn" .= spanEndColumn sourceSpan
    ]

scopeSummaryValue :: ClosedScopeSummary -> Value
scopeSummaryValue summary =
  object
    [ "directOccurrenceCount" .= directOccurrenceCount summary
    , "closedOccurrenceCount" .= closedOccurrenceCount summary
    ]

closedScopeProvenanceValue :: ClosedScopeProvenance -> Value
closedScopeProvenanceValue provenance =
  object
    [ "occurrences"
        .= map
             occurrenceProvenanceValue
             (NonEmpty.toList (closedScopeProvenanceOccurrences provenance))
    ]

occurrenceProvenanceValue :: OccurrenceProvenance -> Value
occurrenceProvenanceValue provenance =
  object
    [ "occurrenceId" .= occurrenceIdText (provenanceOccurrenceId provenance)
    , "location" .= locationValue (provenanceLocation provenance)
    , "inclusionReasons"
        .= map
             inclusionReasonText
             (NonEmpty.toList (provenanceReasons provenance))
    ]

inclusionReasonText :: InclusionReason -> Text
inclusionReasonText reason =
  case reason of
    DirectPresentation -> "direct-presentation"
    RelationshipEndpoint -> "relationship-endpoint"
    ContextOwnership -> "context-ownership"
    PerformanceDimensionMembership -> "performance-dimension-membership"
    SituationDependency -> "situation-dependency"
    NeedDependency -> "need-dependency"
    MacroPremise -> "macro-premise"
    CollectiveRealizationSegment -> "collective-realization-segment"
    CollectiveRealizationParticipant -> "collective-realization-participant"
    CollectiveRealizationContribution -> "collective-realization-contribution"

resolvedViewValue :: ResolvedView SourceLocation -> Value
resolvedViewValue view =
  object
    [ "id" .= resolvedViewId view
    , "name" .= resolvedViewName view
    , "location" .= locationValue (resolvedViewLocation view)
    ]

observedViewValue :: ObservedViewResolution SourceLocation -> Value
observedViewValue observation =
  case observation of
    NoViewMatch -> object ["kind" .= ("none" :: Text)]
    OneViewMatch candidate ->
      object
        ["kind" .= ("one" :: Text), "matches" .= [viewCandidateValue candidate]]
    MultipleViewMatches candidates ->
      object
        [ "kind" .= ("multiple" :: Text)
        , "matches" .= map viewCandidateValue (atLeastTwoToList candidates)
        ]

viewCandidateValue :: ViewCandidate SourceLocation -> Value
viewCandidateValue candidate =
  object
    [ "id" .= viewCandidateId candidate
    , "name" .= viewCandidateName candidate
    , "location" .= locationValue (viewCandidateLocation candidate)
    ]

observedProfileValue :: ObservedO2IProfile -> Value
observedProfileValue observation =
  case observation of
    NoO2IProfile -> object ["kind" .= ("none" :: Text)]
    OneO2IProfile version ->
      object ["kind" .= ("one" :: Text), "values" .= [version]]
    MultipleO2IProfiles versions ->
      object
        ["kind" .= ("multiple" :: Text), "values" .= atLeastTwoToList versions]

encodingObservationValue :: EncodingObservation SourceLocation -> Value
encodingObservationValue observation =
  case observation of
    EncodingNotObserved -> object ["kind" .= ("not-observed" :: Text)]
    EncodingDefaultedToUtf8 -> object ["kind" .= ("utf-8-default" :: Text)]
    EncodingDeclared declaration ->
      object
        [ "kind" .= ("declared" :: Text)
        , "value" .= locatedValue declaration
        , "location" .= locationValue (locatedAt declaration)
        ]

commandErrorValue :: CommandError -> Value
commandErrorValue commandError =
  case commandError of
    InvocationCommandError defect message ->
      commandValue
        "o2i.invocation.invalid"
        InvocationError
        message
        ["defect" .= invocationDefectText defect]
    InputCommandError source message ->
      commandValue
        "o2i.input.read-failed"
        InputIOError
        message
        ["source" .= source]
    StructureInternalCommandError detail ->
      commandValue
        "o2i.internal.structure-elaboration"
        InternalError
        "Structural elaboration failed after model checks passed."
        ["detail" .= detail]

commandValue :: Text -> CommandErrorClassification -> Text -> [Pair] -> Value
commandValue code classification message details =
  object
    [ "code" .= code
    , "classification" .= commandClassificationText classification
    , "message" .= message
    , "data" .= object details
    ]

inspectionStateText :: InspectionReport -> Text
inspectionStateText report =
  case report of
    DecodeRejectedReport {} -> "decode-failed"
    ViewRejectedReport {} -> "view-failed"
    ProfileRejectedReport {} -> "profile-failed"
    ScopeRejectedReport {} -> "scope-failed"
    PipelineReport {} -> "inspected"

inspectionResultText :: InspectionResult -> Text
inspectionResultText result =
  case result of
    InspectionPassed -> "passed"
    InspectionPartial -> "partial"
    InspectionFailed -> "failed"

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

stageStateText :: StageState -> Text
stageStateText state =
  case state of
    StagePassed -> "passed"
    StageFailed -> "failed"
    StageUnavailable -> "unavailable"
    StageNotRun _ -> "not-run"

sourceInputKindText :: SourceInputKind -> Text
sourceInputKindText kind =
  case kind of
    FileSource -> "file"
    StandardInputSource -> "stdin"

severityText :: DiagnosticSeverity -> Text
severityText severity =
  case severity of
    DebugSeverity -> "debug"
    InfoSeverity -> "info"
    WarningSeverity -> "warn"
    ErrorSeverity -> "error"

dispositionText :: DiagnosticDisposition -> Text
dispositionText disposition =
  case disposition of
    ModelFinding -> "model"
    ProcessFailure -> "process"

diagnosticAtomValue :: DiagnosticAtom -> Value
diagnosticAtomValue atom =
  case atom of
    DiagnosticText value -> toJSON value
    DiagnosticInteger value -> toJSON value
    DiagnosticBoolean value -> toJSON value

commandClassificationText :: CommandErrorClassification -> Text
commandClassificationText classification =
  case classification of
    InvocationError -> "invocation"
    InputIOError -> "input-io"
    InternalError -> "internal"

invocationDefectText :: InvocationDefect -> Text
invocationDefectText InvalidInvocation = "invalid-invocation"
