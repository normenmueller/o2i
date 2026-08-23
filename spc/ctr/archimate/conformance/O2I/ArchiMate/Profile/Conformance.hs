{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Build-only public-source conformance corpus owned by the ArchiMate Profile.
--
-- This component is deliberately separate from the production library.  It
-- constructs only public 'Draft.ProfileDraft' values and observes only public
-- Notation results.  In particular it contains neither defect constructors nor
-- a rule/evidence expectation registry.
module O2I.ArchiMate.Profile.Conformance
  ( DuplicateFamily(..)
  , DuplicatePlacement(..)
  , DuplicateCase
  , duplicateCaseFamilies
  , duplicateCasePlacement
  , duplicateCaseMultiplicity
  , duplicateCaseIssueTokens
  , duplicateCaseAffectedOccurrences
  , duplicateCaseTargetCardinalities
  , duplicateCaseObservedFamilies
  , duplicateIdentityCases
  , profileCorpusRuleIds
  , profileCorpusOwnerRuleIds
  , profileCorpusProjectionRuleIds
  , profileCorpusDiagnosticRuleIds
  , profileCorpusDiagnosticEvidenceKinds
  , profileCorpusClassificationRuleIds
  , profileCorpusInvariantRuleIds
  , profileCorpusClassifications
  , profileCorpusClosureRuleIds
  , profileCorpusEvidenceKinds
  , ProfileConformanceFailure
  , foldProfileConformanceFailure
  , ProfileConformanceResult
  , foldProfileConformanceResult
  , foldProfileCorpusOwnerEvidence
  , profileIntegratedBindingSources
  ) where

import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Conformance.Source as Source
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Mapping as Mapping
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Projection
import qualified O2I.ArchiMate.Profile.Resolution as Resolution

-- | The seven closed native record families participating in identity.
--
-- This is verification scenario data, not production dispatch or authority.
data DuplicateFamily
  = ModelRootFamily
  | PropertyDefinitionFamily
  | ElementFamily
  | RelationshipFamily
  | ViewFamily
  | ViewNodeFamily
  | ViewConnectionFamily
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Whether duplicate records are structurally beneath the selected View or
-- outside it.  Global uniqueness must be independent of this distinction.
data DuplicatePlacement
  = SelectedPlacement
  | NonSelectedPlacement
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Observed result of one real public-source duplicate scenario.
data DuplicateCase = DuplicateCase
  { duplicateCaseFamiliesValue :: !(DuplicateFamily, DuplicateFamily)
  , duplicateCasePlacementValue :: !DuplicatePlacement
  , duplicateCaseMultiplicityValue :: !Int
  , duplicateCaseIssueTokensValue :: ![Text]
  , duplicateCaseAffectedOccurrencesValue :: !Int
  , duplicateCaseTargetCardinalitiesValue :: ![Int]
  , duplicateCaseObservedFamiliesValue :: ![DuplicateFamily]
  }

-- | Closed fixture failure, distinct from Profile model evidence.
newtype ProfileConformanceFailure =
  MissingSelectedView Int

-- | Eliminate every closed Profile fixture failure.
foldProfileConformanceFailure ::
     (Int -> result) -> ProfileConformanceFailure -> result
foldProfileConformanceFailure missing failure =
  case failure of
    MissingSelectedView ordinal -> missing ordinal

-- | Closed outcome of producing nominal Profile owner evidence.
data ProfileConformanceResult result
  = ProfileConformanceFailed !(NonEmpty ProfileConformanceFailure)
  | ProfileConformanceObserved ![result]

-- | Eliminate both closed Profile conformance outcomes.
foldProfileConformanceResult ::
     (NonEmpty ProfileConformanceFailure -> result)
  -> ([value] -> result)
  -> ProfileConformanceResult value
  -> result
foldProfileConformanceResult failed observed result =
  case result of
    ProfileConformanceFailed failures -> failed failures
    ProfileConformanceObserved values -> observed values

-- | Families represented by one observed duplicate scenario.
duplicateCaseFamilies :: DuplicateCase -> (DuplicateFamily, DuplicateFamily)
duplicateCaseFamilies = duplicateCaseFamiliesValue

-- | Selected-View placement represented by one duplicate scenario.
duplicateCasePlacement :: DuplicateCase -> DuplicatePlacement
duplicateCasePlacement = duplicateCasePlacementValue

-- | Number of occurrences sharing the duplicated identity.
duplicateCaseMultiplicity :: DuplicateCase -> Int
duplicateCaseMultiplicity = duplicateCaseMultiplicityValue

-- | Public Notation issue tokens emitted for one scenario.
duplicateCaseIssueTokens :: DuplicateCase -> [Text]
duplicateCaseIssueTokens = duplicateCaseIssueTokensValue

-- | Number of duplicate occurrences carrying issue evidence.
duplicateCaseAffectedOccurrences :: DuplicateCase -> Int
duplicateCaseAffectedOccurrences = duplicateCaseAffectedOccurrencesValue

-- | Evidence-target cardinalities observed for the duplicate issues.
duplicateCaseTargetCardinalities :: DuplicateCase -> [Int]
duplicateCaseTargetCardinalities = duplicateCaseTargetCardinalitiesValue

-- | Record families observed through the public production family fold.
duplicateCaseObservedFamilies :: DuplicateCase -> [DuplicateFamily]
duplicateCaseObservedFamilies = duplicateCaseObservedFamiliesValue

-- | Exhaustive 7 self-family plus 21 unordered cross-family source matrix in
-- both meaningful membership placements.  One self-family case additionally
-- proves that groups larger than two are neither collapsed nor normalized.
duplicateIdentityCases :: [DuplicateCase]
duplicateIdentityCases =
  [ observeDuplicateCase left right placement multiplicity
  | (leftIndex, left) <- zip [0 :: Int ..] allFamilies
  , right <- drop leftIndex allFamilies
  , placement <- [minBound .. maxBound]
  , let multiplicity =
          if left == ElementFamily
               && right == ElementFamily
               && placement == SelectedPlacement
            then 3
            else 2
  ]

-- | Every Profile rule identity actually retained by the public owner path for
-- the source corpus.  The value is observational evidence only; callers derive
-- completeness from the independent owner catalog.
profileCorpusRuleIds :: [Text]
profileCorpusRuleIds = concatMap (uncurry observeProfileSource) profileSources

-- | Exact mixed-polar owner rules, excluding separate closure inventory facts.
profileCorpusOwnerRuleIds :: [Text]
profileCorpusOwnerRuleIds =
  concatMap (uncurry observeProfileOwnerSource) profileSources

-- | New negative and positive Projection rules observed by the real corpus.
profileCorpusProjectionRuleIds :: [Text]
profileCorpusProjectionRuleIds =
  concatMap (uncurry observeProfileProjectionRules) profileSources

-- | Profile diagnostic rule identities emitted by real negative sources.
profileCorpusDiagnosticRuleIds :: [Text]
profileCorpusDiagnosticRuleIds =
  concatMap (uncurry observeProfileDiagnostics) profileSources

-- | Negative rule identities paired with the exact public owner evidence kind
-- observed from the exhaustive real-source corpus.
profileCorpusDiagnosticEvidenceKinds :: [(Text, Projection.ProfileEvidenceKind)]
profileCorpusDiagnosticEvidenceKinds =
  concatMap (uncurry observeProfileDiagnosticEvidenceKinds) profileSources

-- | Profile classification rule identities emitted by real source outcomes.
profileCorpusClassificationRuleIds :: [Text]
profileCorpusClassificationRuleIds =
  [rule | (_, _, rule) <- profileCorpusClassifications]

-- | Positive qualification-invariant rule identities retained by projections.
profileCorpusInvariantRuleIds :: [Text]
profileCorpusInvariantRuleIds =
  concatMap (uncurry observeProfileInvariants) profileSources

-- | Graph/qualification branch outcomes paired with their owner rule.
profileCorpusClassifications :: [(Bool, Bool, Text)]
profileCorpusClassifications =
  concatMap (uncurry observeProfileClassifications) profileSources

-- | Closure rule identities retained by real public owner paths.
profileCorpusClosureRuleIds :: [Text]
profileCorpusClosureRuleIds =
  concatMap (uncurry observeProfileClosureRules) profileSources

-- | Every generated Profile evidence form actually retained by the public
-- owner path for the same source corpus.
profileCorpusEvidenceKinds :: [Projection.ProfileEvidenceKind]
profileCorpusEvidenceKinds =
  concatMap (uncurry observeProfileEvidenceKinds) profileSources

-- | Consume every real Profile universe and any resulting projection outcome.
--
-- The selected Profile, universe, and projection assessment retain the same
-- fresh Profile and document indices throughout the callback.
foldProfileCorpusOwnerEvidence ::
     (forall profile document. Resolution.SelectedArchiMateProfile profile -> Closure.ProfileAssessmentUniverse
                                                                                profile
                                                                                document -> Maybe
                                                                                              (Projection.ProfileProjectionAssessment
                                                                                                 profile
                                                                                                 document) -> result)
  -> ProfileConformanceResult result
foldProfileCorpusOwnerEvidence consume =
  case traverse (uncurry observe) profileSources of
    Left failure -> ProfileConformanceFailed (failure :| [])
    Right values -> ProfileConformanceObserved values
  where
    observe source viewOrdinal =
      Resolution.withSelectedArchiMateProfile
        Resolution.compiledProfileDescriptor $ \profile ->
        Notation.withCanonicalDocument source $ \document ->
          case drop viewOrdinal (Notation.canonicalViews document) of
            [] -> Left (MissingSelectedView viewOrdinal)
            view:_ ->
              let universe =
                    Closure.deriveProfileAssessmentUniverse
                      profile
                      document
                      view
                  assessment =
                    Notation.foldStageResult
                      (const Nothing)
                      (Just . Projection.assessSelectedView)
                      (Notation.notationConformance
                         (Notation.assessArchiMateNotation universe))
               in Right (consume profile universe assessment)

-- | Existing real Profile sources for the three reachable Binding outcomes.
--
-- Unknown and out-of-View use the valid Graph source; wrong-kind uses the KPI
-- source whose selected occurrences are real non-Strategy carriers.
profileIntegratedBindingSources :: [(Draft.ProfileDraft, Text)]
profileIntegratedBindingSources =
  [ (Source.validDraft, "unknown")
  , (Source.validDraft, "model")
  , (Source.validKpiDraft, "kpi")
  ]

profileSources :: [(Draft.ProfileDraft, Int)]
profileSources =
  [ (Source.validDraft, 0)
  , (Source.validDraftPermuted, 0)
  , (Source.validKpiDraft, 0)
  , (Source.invalidCarrierDraft, 0)
  , (Source.unmarkedDisplayedDraft, 0)
  , (Source.qualificationDraft, 0)
  , (Source.qualificationMissingRoleDraft, 0)
  , (Source.qualificationWrongRoleDraft, 0)
  , (Source.qualificationMultipleInvalidRoleValuesDraft, 0)
  , (Source.qualificationWrongRelationshipDraft, 0)
  , (Source.qualificationWrongDirectionDraft, 0)
  , (Source.qualificationNonProposalRoleDraft, 0)
  , (Source.qualificationWrongCarrierDraft, 0)
  , (Source.qualificationInvalidTypeDraft, 0)
  , (Source.qualificationNoRationaleDraft, 0)
  , (Source.qualificationNormalizedRationaleDraft, 0)
  , (Source.qualificationMultipleRationaleDraft, 0)
  , (Source.qualificationInvalidRationaleDraft, 0)
  , (Source.qualificationNormalizedSourcesDraft, 0)
  , (Source.qualificationContextualizedDraft, 0)
  , (Source.graphPropertyDefinitionDraft, 0)
  , (Source.qualificationPropertyDefinitionDraft, 0)
  , (Source.collectiveClosedDraft, 0)
  , (Source.collectiveOpenDraft, 0)
  , (Source.collectiveChainDraft, 0)
  , (Source.collectiveWrongCarrierDraft, 0)
  , (Source.collectiveInvalidTypeDraft, 0)
  , (Source.branchIsolationDraft, 0)
  , (Source.branchIsolationDraft, 1)
  ]
    <> map (\source -> (source, 0)) Source.ownerConformanceMutationDrafts
    <> map relationSource Mapping.relationMappings
    <> concatMap carrierSources Mapping.carrierMappings
  where
    relationSource mapping =
      ( Source.relationApplicabilityDraft
          (Mapping.relationMappingRelationship mapping)
          (Mapping.relationMappingAssociationDirected mapping)
          (Mapping.relationMappingLabel mapping)
          "Grouping"
          "Strategy"
          "Grouping"
          "Strategy"
      , 0)
    carrierSources mapping =
      [ ( Source.relationApplicabilityDraft
            "AssociationRelationship"
            True
            "qualifies"
            (Mapping.carrierMappingElement mapping)
            o2iType
            (Mapping.carrierMappingElement mapping)
            o2iType
        , 0)
      | o2iType <- Mapping.carrierMappingTypes mapping
      ]

observeProfileSource :: Draft.ProfileDraft -> Int -> [Text]
observeProfileSource source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse profile document view
              activationRules =
                concatMap
                  activationRuleIds
                  (Closure.assessmentActivationProvenance universe)
              closureRules =
                map closureRuleId (Closure.assessmentClosureProvenance universe)
           in activationRules
                <> closureRules
                <> Notation.foldStageResult
                     (const [])
                     projectionRuleIds
                     (Notation.notationConformance
                        (Notation.assessArchiMateNotation universe))

observeProfileProjectionRules :: Draft.ProfileDraft -> Int -> [Text]
observeProfileProjectionRules source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse profile document view
           in Notation.foldStageResult
                (const [])
                projectionRuleIds
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

observeProfileOwnerSource :: Draft.ProfileDraft -> Int -> [Text]
observeProfileOwnerSource source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse profile document view
              activationRules =
                concatMap
                  activationRuleIds
                  (Closure.assessmentActivationProvenance universe)
           in activationRules
                <> Notation.foldStageResult
                     (const [])
                     projectionRuleIds
                     (Notation.notationConformance
                        (Notation.assessArchiMateNotation universe))

observeProfileEvidenceKinds ::
     Draft.ProfileDraft -> Int -> [Projection.ProfileEvidenceKind]
observeProfileEvidenceKinds source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse profile document view
           in Notation.foldStageResult
                (const [])
                projectionEvidenceKinds
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

observeProfileDiagnostics :: Draft.ProfileDraft -> Int -> [Text]
observeProfileDiagnostics source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse profile document view
           in Notation.foldStageResult
                (const [])
                projectionDiagnosticRuleIds
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

observeProfileDiagnosticEvidenceKinds ::
     Draft.ProfileDraft -> Int -> [(Text, Projection.ProfileEvidenceKind)]
observeProfileDiagnosticEvidenceKinds source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse profile document view
           in Notation.foldStageResult
                (const [])
                projectionDiagnosticEvidenceKinds
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

observeProfileClosureRules :: Draft.ProfileDraft -> Int -> [Text]
observeProfileClosureRules source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          map
            closureRuleId
            (Closure.assessmentClosureProvenance
               (Closure.deriveProfileAssessmentUniverse profile document view))

activationRuleIds :: Closure.ActivationProvenance profile document -> [Text]
activationRuleIds =
  Closure.foldActivationProvenance
    (\_ _ _ rule _ _ sourceRules -> rule : sourceRules)

closureRuleId :: Closure.ClosureProvenance profile document -> Text
closureRuleId = Closure.foldClosureProvenance (\_ _ _ rule _ _ _ -> rule)

projectionRuleIds ::
     Notation.NotationConformantUniverse profile document -> [Text]
projectionRuleIds conformant =
  Projection.foldProfileProjectionAssessment
    (const [])
    (map Projection.profileDiagnosticRuleId . NonEmpty.toList)
    (\projection ->
       map
         classificationRuleId
         (Projection.profileClassificationEvidence projection)
         <> map mappingRuleId (Projection.profileMappingProvenance projection)
         <> map
              invariantRuleId
              (Projection.profileQualificationInvariantEvidence projection))
    (Projection.assessSelectedView conformant)

observeProfileClassifications ::
     Draft.ProfileDraft -> Int -> [(Bool, Bool, Text)]
observeProfileClassifications source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse profile document view
           in Notation.foldStageResult
                (const [])
                (\conformant ->
                   Projection.foldProfileProjectionAssessment
                     (const [])
                     (const [])
                     (map classificationObservation
                        . Projection.profileClassificationEvidence)
                     (Projection.assessSelectedView conformant))
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

classificationRuleId ::
     Projection.ProfileClassificationEvidence profile document -> Text
classificationRuleId =
  Projection.foldProfileClassificationEvidence (\_ _ rule _ -> rule)

classificationObservation ::
     Projection.ProfileClassificationEvidence profile document
  -> (Bool, Bool, Text)
classificationObservation =
  Projection.foldProfileClassificationEvidence
    (\graph qualification rule _ -> (graph, qualification, rule))

projectionDiagnosticRuleIds ::
     Notation.NotationConformantUniverse profile document -> [Text]
projectionDiagnosticRuleIds conformant =
  Projection.foldProfileProjectionAssessment
    (const [])
    (map Projection.profileDiagnosticRuleId . NonEmpty.toList)
    (const [])
    (Projection.assessSelectedView conformant)

projectionDiagnosticEvidenceKinds ::
     Notation.NotationConformantUniverse profile document
  -> [(Text, Projection.ProfileEvidenceKind)]
projectionDiagnosticEvidenceKinds conformant =
  Projection.foldProfileProjectionAssessment
    (const [])
    (map
       (Projection.foldProfileDiagnosticEvidence $ \rule evidence ->
          (rule, Projection.profileEvidenceKind evidence))
       . NonEmpty.toList)
    (const [])
    (Projection.assessSelectedView conformant)

observeProfileInvariants :: Draft.ProfileDraft -> Int -> [Text]
observeProfileInvariants source viewOrdinal =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    Notation.withCanonicalDocument source $ \document ->
      case drop viewOrdinal (Notation.canonicalViews document) of
        [] -> []
        view:_ ->
          let universe =
                Closure.deriveProfileAssessmentUniverse profile document view
           in Notation.foldStageResult
                (const [])
                (\conformant ->
                   Projection.foldProfileProjectionAssessment
                     (const [])
                     (const [])
                     (map invariantRuleId
                        . Projection.profileQualificationInvariantEvidence)
                     (Projection.assessSelectedView conformant))
                (Notation.notationConformance
                   (Notation.assessArchiMateNotation universe))

projectionEvidenceKinds ::
     Notation.NotationConformantUniverse profile document
  -> [Projection.ProfileEvidenceKind]
projectionEvidenceKinds conformant =
  Projection.foldProfileProjectionAssessment
    (const [])
    (map
       (Projection.foldProfileDiagnosticEvidence
          (\_ evidence -> Projection.profileEvidenceKind evidence))
       . NonEmpty.toList)
    (\projection ->
       map
         Projection.profileMappingEvidenceKind
         (Projection.profileMappingProvenance projection)
         <> map
              invariantEvidenceKind
              (Projection.profileQualificationInvariantEvidence projection))
    (Projection.assessSelectedView conformant)

mappingRuleId :: Projection.ProfileMappingProvenance profile document -> Text
mappingRuleId =
  Projection.foldProfileMappingProvenance
    (\rule _ _ -> rule)
    (\rule _ _ _ _ -> rule)
    (\rule _ _ -> rule)

invariantRuleId :: Projection.ProfileInvariantEvidence profile document -> Text
invariantRuleId = Projection.foldProfileInvariantEvidence (\rule _ -> rule)

invariantEvidenceKind ::
     Projection.ProfileInvariantEvidence profile document
  -> Projection.ProfileEvidenceKind
invariantEvidenceKind =
  Projection.foldProfileInvariantEvidence
    (\_ evidence -> Projection.profileEvidenceKind evidence)

allFamilies :: [DuplicateFamily]
allFamilies = [minBound .. maxBound]

observeDuplicateCase ::
     DuplicateFamily
  -> DuplicateFamily
  -> DuplicatePlacement
  -> Int
  -> DuplicateCase
observeDuplicateCase left right placement multiplicity =
  Notation.withCanonicalDocument source $ \document ->
    let duplicateIssues =
          filter
            ((`elem` duplicateTokens)
               . Notation.archiMateNotationIssueKindToken
               . Notation.archiMateNotationIssueKind)
            (Notation.assessCanonicalViewInventory document)
        targetCardinalities =
          map
            (maximumOrZero
               . map evidenceTargetCardinality
               . NonEmpty.toList
               . Notation.archiMateNotationIssueEvidence)
            duplicateIssues
     in DuplicateCase
          (left, right)
          placement
          multiplicity
          (map
             (Notation.archiMateNotationIssueKindToken
                . Notation.archiMateNotationIssueKind)
             duplicateIssues)
          (length duplicateIssues)
          targetCardinalities
          (map
             observedCanonicalFamily
             (drop 2 (Notation.canonicalDocumentRecords document)))
  where
    source = duplicateDraft left right placement multiplicity

duplicateTokens :: [Text]
duplicateTokens =
  [ "model-identity-duplicate"
  , "view-identity-duplicate"
  , "record-identity-duplicate"
  ]

evidenceTargetCardinality :: Notation.ArchiMateNotationEvidence -> Int
evidenceTargetCardinality =
  Notation.foldArchiMateNotationEvidence
    (const 0)
    (\_ _ _ -> 0)
    (\_ _ targets -> length targets)

maximumOrZero :: [Int] -> Int
maximumOrZero = foldr max 0

data SomeDraftRecord =
  forall recordRole. SomeDraftRecord (Draft.DraftRecord recordRole)

observedCanonicalFamily :: Notation.CanonicalRecord -> DuplicateFamily
observedCanonicalFamily =
  Notation.foldCanonicalRecord (\_ family _ _ _ -> observedFamily family)

observedFamily :: Draft.DraftRecordFamilyValue -> DuplicateFamily
observedFamily =
  Draft.foldDraftRecordFamilyValue
    ModelRootFamily
    PropertyDefinitionFamily
    ElementFamily
    RelationshipFamily
    ViewFamily
    ViewNodeFamily
    ViewConnectionFamily

duplicateDraft ::
     DuplicateFamily
  -> DuplicateFamily
  -> DuplicatePlacement
  -> Int
  -> Draft.ProfileDraft
duplicateDraft left right placement multiplicity =
  Draft.profileDraft
    (Draft.modelRootDraft
       (identity "outer-model")
       (location "outer-model")
       rootMembers)
  where
    duplicateFamilies =
      if left == right
        then replicate multiplicity left
        else left : right : replicate (multiplicity - 2) right
    duplicateMembers =
      [ Draft.childRecordMember record
      | (ordinal, family) <- zip [1 :: Int ..] duplicateFamilies
      , SomeDraftRecord record <- [familyRecord family ordinal]
      ]
    selectedView =
      Draft.viewDraft
        (identity "selected-view")
        (location "selected-view")
        (case placement of
           SelectedPlacement -> duplicateMembers
           NonSelectedPlacement -> [])
    rootMembers =
      Draft.childRecordMember selectedView
        : case placement of
            SelectedPlacement -> []
            NonSelectedPlacement -> duplicateMembers

familyRecord :: DuplicateFamily -> Int -> SomeDraftRecord
familyRecord family ordinal =
  let recordLocation = location ("duplicate-" <> renderOrdinal ordinal)
      recordIdentity = identity "duplicate"
   in case family of
        ModelRootFamily ->
          SomeDraftRecord
            (Draft.modelRootDraft recordIdentity recordLocation [])
        PropertyDefinitionFamily ->
          SomeDraftRecord
            (Draft.propertyDefinitionDraft recordIdentity recordLocation [])
        ElementFamily ->
          SomeDraftRecord (Draft.elementDraft recordIdentity recordLocation [])
        RelationshipFamily ->
          SomeDraftRecord
            (Draft.relationshipDraft recordIdentity recordLocation [])
        ViewFamily ->
          SomeDraftRecord (Draft.viewDraft recordIdentity recordLocation [])
        ViewNodeFamily ->
          SomeDraftRecord (Draft.viewNodeDraft recordIdentity recordLocation [])
        ViewConnectionFamily ->
          SomeDraftRecord
            (Draft.viewConnectionDraft recordIdentity recordLocation [])

identity :: Text -> Draft.DraftIdentity recordRole
identity value =
  Draft.draftIdentity [Draft.draftTextScalar value (location value)]

location :: Text -> Draft.DraftLocation
location name =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing name) 0)
       [])
    Nothing

renderOrdinal :: Int -> Text
renderOrdinal ordinal =
  case ordinal of
    1 -> "one"
    2 -> "two"
    _ -> "three"
