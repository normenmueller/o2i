{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}

module O2I.ArchiMate.Profile.Internal.Projection where

import Data.Char (ord)
import Data.List (find, sortOn)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Normalize (NormalizationMode(NFC), normalize)
import O2I.ArchiMate.Profile.Internal.Closure
  ( ClassificationProvenance
  , ClosedView
  , closedViewClassificationProvenanceValue
  , closedViewDisplayedOccurrencesValue
  , closedViewDocumentValue
  , closedViewGraphOccurrencesValue
  , closedViewIndexValue
  , closedViewQualificationOccurrencesValue
  , closedViewQualificationProposalOccurrencesValue
  , closedViewUniverseValue
  , displayedSubjectOccurrenceValue
  )
import O2I.ArchiMate.Profile.Internal.Closure.Witness
  ( profileAssessmentUniverseValue
  )
import O2I.ArchiMate.Profile.Internal.Draft
import O2I.ArchiMate.Profile.Internal.Generated
  ( GeneratedCardinalityExpectation(..)
  , GeneratedProfileDefectRule
  , GeneratedProfileEvidenceKind(..)
  , GeneratedPropertyConstraint(..)
  , GeneratedPropertyRuntimePlan(..)
  , GeneratedQualificationInvariantRule
  , GeneratedRelationMapping(..)
  , GeneratedRuntimeExpected(..)
  , generatedCarrierOccurrenceDefectRule
  , generatedClassificationOccurrenceDefectRule
  , generatedMetadataOwnerAndO2iPropertyOccurrencesDefectRule
  , generatedProfileDefectRuleId
  , generatedProfileRuleIds
  , generatedPropertyOccurrenceEvidenceDefectRule
  , generatedPropertyRuntimePlans
  , generatedPropertySlotEvidenceDefectRule
  , generatedPropertyValueEvidenceDefectRule
  , generatedProposalCarrierOccurrenceDefectRule
  , generatedProposalReferenceIncidenceDefectRule
  , generatedQualificationProposalCategoryRule
  , generatedQualificationProposalStableIdentityScopeRule
  , generatedRelationMappings
  , generatedRelationshipOccurrenceDefectRule
  , generatedReservedPropertyOccurrenceDefectRule
  , generatedStructuredCarrierOccurrenceDefectRule
  , generatedStructuredIncidenceDefectRule
  )
import O2I.ArchiMate.Profile.Internal.Index
import O2I.ArchiMate.Profile.Internal.Mapping
import O2I.ArchiMate.Profile.Internal.Notation
import O2I.ArchiMate.Profile.Internal.Notation.Conformance
  ( NotationConformantUniverse
  , notationConformantUniverseValue
  )
import O2I.Core.Contract
  ( CoreQualificationProposalRoleId
  , CoreStructuredPropositionRoleId
  , lookupCoreCarrierCategory
  , lookupCoreO2IType
  , lookupCoreParticipantCompletenessToken
  , lookupCoreQualificationProposalRoleId
  , lookupCoreRelationToken
  , lookupCoreStructuredPropositionFamilyId
  , lookupCoreStructuredPropositionRoleId
  )
import O2I.Core.Graph.Observation (Commitment(..))
import O2I.Core.Identity
  ( ModelIdentity
  , ModelOccurrence
  , OccurrenceIdentity
  , OccurrenceIdentityDefect
  , modelIdentity
  , modelOccurrence
  , occurrenceIdentity
  )
import O2I.Structure
  ( CarrierProjection
  , ContextualizationProjection
  , RelationProjection
  , StructureProjection
  , StructuredIncidenceProjection
  , StructuredPropositionProjection
  , carrierProjection
  , contextualizationProjection
  , relationProjection
  , structureProjection
  , structuredIncidenceProjection
  , structuredPropositionProjection
  )

-- | Canonical notation evidence indexed by its generated evidence kind.
data ProfileEvidence (kind :: GeneratedProfileEvidenceKind) where
  CarrierOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'GeneratedProfileEvidenceCarrierOccurrence
  ClassificationOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'GeneratedProfileEvidenceClassificationOccurrence
  MetadataOwnerAndO2iPropertyOccurrencesEvidence
    :: !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence
         'GeneratedProfileEvidenceMetadataOwnerAndO2iPropertyOccurrences
  PropertyOccurrenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ProfileEvidence 'GeneratedProfileEvidencePropertyOccurrenceEvidence
  PropertySlotEvidence
    :: !CanonicalOccurrence
    -> !Text
    -> ![CanonicalOccurrence]
    -> ProfileEvidence 'GeneratedProfileEvidencePropertySlotEvidence
  PropertyValueEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ![DraftScalar]
    -> ProfileEvidence 'GeneratedProfileEvidencePropertyValueEvidence
  ProposalCarrierOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'GeneratedProfileEvidenceProposalCarrierOccurrence
  ProposalReferenceIncidenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence 'GeneratedProfileEvidenceProposalReferenceIncidence
  RelationshipOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'GeneratedProfileEvidenceRelationshipOccurrence
  ReservedPropertyOccurrenceEvidence
    :: !CanonicalOccurrence
    -> !CanonicalOccurrence
    -> !Text
    -> ProfileEvidence 'GeneratedProfileEvidenceReservedPropertyOccurrence
  StructuredCarrierOccurrenceEvidence
    :: !CanonicalOccurrence
    -> ProfileEvidence 'GeneratedProfileEvidenceStructuredCarrierOccurrence
  StructuredIncidenceEvidence
    :: !CanonicalOccurrence
    -> ![CanonicalOccurrence]
    -> ProfileEvidence 'GeneratedProfileEvidenceStructuredIncidence

deriving instance Show (ProfileEvidence kind)

-- | One generated rule paired only with evidence of its declared kind.
data ProfileDefect where
  ProfileDefect
    :: !(GeneratedProfileDefectRule kind)
    -> !(ProfileEvidence kind)
    -> ProfileDefect

instance Eq ProfileDefect where
  left == right = defectOrder left == defectOrder right

instance Ord ProfileDefect where
  compare left right = compare (defectOrder left) (defectOrder right)

instance Show ProfileDefect where
  show (ProfileDefect rule evidence) =
    "ProfileDefect "
      ++ show (generatedProfileDefectRuleId rule)
      ++ " "
      ++ show evidence

-- | Closed failures in the compiled Profile/Core integration contract.
data ProfileContractFailure
  = UnknownGeneratedProfileRule !Text !GeneratedProfileEvidenceKind
  | GeneratedProfileEvidenceMismatch !Text !GeneratedProfileEvidenceKind
  | MissingCoreContractBinding !Text !CanonicalOccurrence
  | ImpossibleOccurrenceIdentity !CanonicalOccurrence !Text
  deriving (Eq, Ord, Show)

data ProfileIssue
  = ProfileModelDefect !ProfileDefect
  | ProfileContractFailure !ProfileContractFailure
  deriving (Eq, Ord, Show)

-- | One role-labelled reference retained by a qualification proposal.
data QualificationReference = QualificationReference
  { qualificationReferenceOccurrenceValue :: !OccurrenceIdentity
  , qualificationReferenceRoleValue :: !CoreQualificationProposalRoleId
  , qualificationReferenceTargetValue :: !OccurrenceIdentity
  } deriving (Eq, Ord, Show)

-- | One source occurrence retained by a qualification proposal.
data QualificationSource = QualificationSource
  { qualificationSourceOccurrenceValue :: !OccurrenceIdentity
  , qualificationSourceValueValue :: !Text
  } deriving (Eq, Ord, Show)

-- | One preserved documentation occurrence and its normalized rationale.
data QualificationRationale = QualificationRationale
  { qualificationRationaleOccurrenceValue :: !DraftLocation
  , qualificationRationaleValueValue :: !Text
  } deriving (Eq, Ord, Show)

-- | One concrete qualification proposal retained outside Core Structure.
data QualificationProposal = QualificationProposal
  { qualificationProposalOccurrenceValue :: !OccurrenceIdentity
  , qualificationProposalIdentityValue :: !ModelIdentity
  , qualificationProposalRationaleValue :: !(Maybe QualificationRationale)
  , qualificationProposalSourcesValue :: ![QualificationSource]
  , qualificationProposalReferencesValue :: ![QualificationReference]
  } deriving (Eq, Show)

-- | One generated positive qualification invariant paired with the existing
-- proposal-carrier occurrence evidence form.
data ProfileInvariantEvidence =
  ProfileInvariantEvidence
    !GeneratedQualificationInvariantRule
    !(ProfileEvidence 'GeneratedProfileEvidenceProposalCarrierOccurrence)
  deriving (Show)

-- | One successfully constructed proposal and its constant positive evidence.
data QualificationProjection = QualificationProjection
  { qualificationProjectionProposal :: !QualificationProposal
  , qualificationProjectionMappingProvenance :: ![ProfileMappingProvenance]
  , qualificationProjectionInvariantEvidence :: ![ProfileInvariantEvidence]
  }

-- | One concrete Profile mapping retained independently of Core semantics.
data ProfileMappingProvenance
  = CarrierMappingProvenance !OccurrenceIdentity !Text !Text
  | RelationMappingProvenance
      !OccurrenceIdentity
      !Text
      !Text
      !OccurrenceIdentity
      !OccurrenceIdentity
  | ConstructionMappingProvenance
      !OccurrenceIdentity
      !Text
      !Text
      !GeneratedProfileEvidenceKind
  deriving (Eq, Ord, Show)

-- | Accepted Core Structure plus retained qualification proposals.
data ProfileProjection = ProfileProjection
  { profileStructureProjectionValue :: !StructureProjection
  , profileModelIdentityOccurrencesValue :: ![ModelOccurrence]
  , profileSelectedOccurrencesValue :: ![OccurrenceIdentity]
  , profileClassificationProvenanceValue :: ![ClassificationProvenance]
  , profileMappingProvenanceValue :: ![ProfileMappingProvenance]
  , profileQualificationProposalsValue :: ![QualificationProposal]
  , profileInvariantEvidenceValue :: ![ProfileInvariantEvidence]
  }

-- | Closed outcome of applying the compiled Profile projection contract.
data ProfileProjectionAssessment
  = ProfileContractFailed !(NonEmpty ProfileContractFailure)
  | ProfileRejected !(NonEmpty ProfileDefect)
  | ProfileAccepted !ProfileProjection

data ProjectionResult value = ProjectionResult
  { projectionIssues :: ![ProfileIssue]
  , projectionValues :: ![value]
  }

data RelationshipResult = RelationshipResult
  { relationshipIssues :: ![ProfileIssue]
  , relationshipRelations :: ![RelationProjection]
  , relationshipContextualizations :: ![ContextualizationProjection]
  , relationshipMappingProvenance :: ![ProfileMappingProvenance]
  }

data StructuredResult = StructuredResult
  { structuredIssues :: ![ProfileIssue]
  , structuredPropositions :: ![StructuredPropositionProjection]
  , structuredIncidences :: ![StructuredIncidenceProjection]
  , structuredMappingProvenance :: ![ProfileMappingProvenance]
  }

data TextNormalization
  = DocumentationNormalization
  | NonEmptyScalarNormalization
  deriving (Eq)

patternExpectation ::
     PatternExpectation value
  -> Text
  -> CanonicalOccurrence
  -> Either [ProfileIssue] (Text, value)
patternExpectation expectation subject occurrence =
  case lookupPatternExpectation expectation subject of
    Just expected -> Right expected
    Nothing -> invalidPatternRuntimeExpectation subject occurrence

patternTextExpectation ::
     Text -> CanonicalOccurrence -> Either [ProfileIssue] (Text, Text)
patternTextExpectation = patternExpectation PatternTextExpectation

patternTextsExpectation ::
     Text -> CanonicalOccurrence -> Either [ProfileIssue] (Text, [Text])
patternTextsExpectation = patternExpectation PatternTextsExpectation

patternBooleanExpectation ::
     Text -> CanonicalOccurrence -> Either [ProfileIssue] (Text, Bool)
patternBooleanExpectation = patternExpectation PatternBooleanExpectation

invalidPatternRuntimeExpectation ::
     Text -> CanonicalOccurrence -> Either [ProfileIssue] value
invalidPatternRuntimeExpectation subject occurrence =
  Left
    [ contractIssue
        (MissingCoreContractBinding
           ("generated-pattern-runtime-expectation:" <> subject)
           occurrence)
    ]

patternTextIssues ::
     Text
  -> CanonicalOccurrence
  -> Text
  -> (Text -> ProfileIssue)
  -> [ProfileIssue]
patternTextIssues subject occurrence actual issue =
  case patternTextExpectation subject occurrence of
    Left issues -> issues
    Right (rule, expected)
      | actual == expected -> []
      | otherwise -> [issue rule]

patternBooleanIssues ::
     Text
  -> CanonicalOccurrence
  -> Bool
  -> (Text -> ProfileIssue)
  -> [ProfileIssue]
patternBooleanIssues subject occurrence actual issue =
  case patternBooleanExpectation subject occurrence of
    Left issues -> issues
    Right (rule, expected)
      | actual == expected -> []
      | otherwise -> [issue rule]

patternTextsIssues ::
     Text
  -> CanonicalOccurrence
  -> Text
  -> (Text -> ProfileIssue)
  -> [ProfileIssue]
patternTextsIssues subject occurrence actual issue =
  case patternTextsExpectation subject occurrence of
    Left issues -> issues
    Right (rule, expected)
      | actual `elem` expected -> []
      | otherwise -> [issue rule]

patternForbiddenIssues ::
     Text
  -> CanonicalOccurrence
  -> Bool
  -> (Text -> ProfileIssue)
  -> [ProfileIssue]
patternForbiddenIssues subject occurrence violation issue =
  case patternTextExpectation subject occurrence of
    Left issues -> issues
    Right (rule, "forbidden")
      | violation -> [issue rule]
      | otherwise -> []
    Right _ ->
      resultErrors (invalidPatternRuntimeExpectation subject occurrence)

patternTextMappingProvenance ::
     Text
  -> Text
  -> Text
  -> GeneratedProfileEvidenceKind
  -> CanonicalOccurrence
  -> OccurrenceIdentity
  -> ProjectionResult ProfileMappingProvenance
patternTextMappingProvenance subject actual mappingId evidenceKind owner occurrence =
  case patternTextExpectation subject owner of
    Left issues -> ProjectionResult issues []
    Right (rule, expected)
      | actual == expected ->
        ProjectionResult
          []
          [ConstructionMappingProvenance occurrence rule mappingId evidenceKind]
      | otherwise ->
        ProjectionResult
          [ contractIssue
              (MissingCoreContractBinding
                 ("generated-positive-pattern-mapping:" <> subject)
                 owner)
          ]
          []

patternTextsMappingProvenance ::
     Text
  -> Text
  -> Text
  -> GeneratedProfileEvidenceKind
  -> CanonicalOccurrence
  -> OccurrenceIdentity
  -> ProjectionResult ProfileMappingProvenance
patternTextsMappingProvenance subject actual mappingId evidenceKind owner occurrence =
  case patternTextsExpectation subject owner of
    Left issues -> ProjectionResult issues []
    Right (rule, expected)
      | actual `elem` expected ->
        ProjectionResult
          []
          [ConstructionMappingProvenance occurrence rule mappingId evidenceKind]
      | otherwise ->
        ProjectionResult
          [ contractIssue
              (MissingCoreContractBinding
                 ("generated-positive-pattern-mapping:" <> subject)
                 owner)
          ]
          []

propertyCardinalityMappingProvenance ::
     Text
  -> CanonicalOccurrence
  -> OccurrenceIdentity
  -> ProjectionResult ProfileMappingProvenance
propertyCardinalityMappingProvenance mappingId owner occurrence =
  case filter
         ((== mappingId) . generatedPropertyRuntimeMappingId)
         generatedPropertyRuntimePlans of
    [plan] ->
      ProjectionResult
        []
        [ ConstructionMappingProvenance
            occurrence
            (generatedPropertyRuntimePropertyCardinalityRuleId plan)
            mappingId
            GeneratedProfileEvidencePropertySlotEvidence
        ]
    _ ->
      ProjectionResult
        [ contractIssue
            (MissingCoreContractBinding
               ("generated-positive-property-mapping:" <> mappingId)
               owner)
        ]
        []

projectClosedProfile :: ClosedView -> ProfileProjectionAssessment
projectClosedProfile closed =
  case NonEmpty.nonEmpty contractFailures of
    Just failures -> ProfileContractFailed failures
    Nothing ->
      case NonEmpty.nonEmpty modelDefects of
        Just defects -> ProfileRejected defects
        Nothing ->
          ProfileAccepted
            ProfileProjection
              { profileStructureProjectionValue =
                  structureProjection
                    carriers
                    contextualizations
                    relations
                    propositions
                    incidences
              , profileModelIdentityOccurrencesValue =
                  mapMaybe
                    canonicalModelOccurrence
                    (canonicalIdentityDomainValue
                       (closedViewDocumentValue closed))
              , profileSelectedOccurrencesValue =
                  mapMaybe
                    (either (const Nothing) Just
                       . canonicalOccurrenceIdentityValue)
                    (Set.toAscList (graph `Set.intersection` recordOccurrences))
              , profileClassificationProvenanceValue =
                  closedViewClassificationProvenanceValue closed
              , profileMappingProvenanceValue =
                  sortOn
                    mappingProvenanceOccurrence
                    (carrierMappingProvenance
                       ++ relationMappingProvenance
                       ++ structuredConstructionProvenance
                       ++ qualificationMappingProvenance)
              , profileQualificationProposalsValue = proposals
              , profileInvariantEvidenceValue = invariantEvidence
              }
  where
    projectionIndex = closedViewIndexValue closed
    graph = closedViewGraphOccurrencesValue closed
    qualification = closedViewQualificationOccurrencesValue closed
    qualificationProposals =
      closedViewQualificationProposalOccurrencesValue closed
    universe = closedViewUniverseValue closed
    recordOccurrences =
      Set.fromList
        (map
           canonicalRecordOccurrenceValue
           (canonicalIdentityDomainValue (closedViewDocumentValue closed)))
    scopeSeed =
      indexModelRoots projectionIndex
        `Set.union` Set.fromList
                      (map
                         displayedSubjectOccurrenceValue
                         (closedViewDisplayedOccurrencesValue closed))
    preActivationProperties =
      Set.fromList
        [ propertyInfoOccurrence property
        | owner <- Set.toAscList scopeSeed
        , property <- propertiesFor projectionIndex owner
        ]
    graphRecords = recordsIn projectionIndex graph
    qualificationRecords = recordsIn projectionIndex qualification
    namespaceIssues =
      reservedNamespaceIssues
        projectionIndex
        qualificationProposals
        preActivationProperties
        ++ reservedNamespaceIssues
             projectionIndex
             qualificationProposals
             (universe `Set.difference` preActivationProperties)
    structuredRecords =
      [ record
      | record <- graphRecords
      , isStructuredCandidate projectionIndex record
      ]
    structuredCarriers =
      Set.fromList (map recordInfoOccurrence structuredRecords)
    graphRelationships = relationshipsIn projectionIndex graph
    structuredSegments =
      Map.fromListWith
        (flip (++))
        [ (owner, [relationship])
        | relationship <- graphRelationships
        , owner <-
            take 1 (incidentStructuredCarriers structuredCarriers relationship)
        ]
    structuredRelationships =
      Set.fromList
        [ relationshipInfoOccurrence relationship
        | relationships <- Map.elems structuredSegments
        , relationship <- relationships
        ]
    carrierResults =
      map (projectCarrier projectionIndex qualificationProposals) graphRecords
    relationshipResults =
      map
        (projectRelationship projectionIndex)
        [ relationship
        | relationship <- graphRelationships
        , relationshipInfoOccurrence relationship
            `Set.notMember` structuredRelationships
        ]
    structuredResults =
      [ projectStructured
        projectionIndex
        structuredCarriers
        (Map.findWithDefault [] (recordInfoOccurrence record) structuredSegments)
        record
      | record <- structuredRecords
      ]
    proposalResults =
      map
        (projectQualificationProposal projectionIndex qualification)
        [ record
        | record <- qualificationRecords
        , recordInfoOccurrence record `Set.member` qualificationProposals
        ]
    carrierIssues = concatMap projectionIssues carrierResults
    carrierProjections = concatMap projectionValues carrierResults
    carriers = map fst carrierProjections
    carrierMappingProvenance = map snd carrierProjections
    relationIssues = concatMap relationshipIssues relationshipResults
    relations = concatMap relationshipRelations relationshipResults
    contextualizations =
      concatMap relationshipContextualizations relationshipResults
    relationMappingProvenance =
      concatMap relationshipMappingProvenance relationshipResults
    structuredIssues' = concatMap structuredIssues structuredResults
    propositions = concatMap structuredPropositions structuredResults
    incidences = concatMap structuredIncidences structuredResults
    structuredConstructionProvenance =
      concatMap structuredMappingProvenance structuredResults
    proposalIssues = concatMap projectionIssues proposalResults
    qualificationProjections = concatMap projectionValues proposalResults
    proposals = map qualificationProjectionProposal qualificationProjections
    qualificationMappingProvenance =
      concatMap
        qualificationProjectionMappingProvenance
        qualificationProjections
    invariantEvidence =
      concatMap
        qualificationProjectionInvariantEvidence
        qualificationProjections
    allIssues =
      sortOn
        issueOrder
        (namespaceIssues
           ++ carrierIssues
           ++ relationIssues
           ++ structuredIssues'
           ++ proposalIssues)
    contractFailures = [failure | ProfileContractFailure failure <- allIssues]
    modelDefects =
      [profileDefect | ProfileModelDefect profileDefect <- allIssues]

canonicalModelOccurrence :: CanonicalRecord -> Maybe ModelOccurrence
canonicalModelOccurrence record =
  case ( canonicalOccurrenceIdentityValue
           (canonicalRecordOccurrenceValue record)
       , canonicalRecordIdentityValue record) of
    (Right occurrence, IdentityResolved _ identifier) ->
      Just (modelOccurrence occurrence identifier)
    _ -> Nothing

-- | Apply selected-Profile rules only after exact Notation conformance.
assessSelectedViewValue ::
     NotationConformantUniverse profile document -> ProfileProjectionAssessment
assessSelectedViewValue =
  projectClosedProfile
    . profileAssessmentUniverseValue
    . notationConformantUniverseValue

issueOrder ::
     ProfileIssue
  -> ( CanonicalOccurrence
     , Text
     , GeneratedProfileEvidenceKind
     , [CanonicalOccurrence]
     , Text
     , [DraftScalar])
issueOrder issue =
  case issue of
    ProfileModelDefect profileDefect -> defectOrder profileDefect
    ProfileContractFailure failure -> contractFailureOrder failure

defectOrder ::
     ProfileDefect
  -> ( CanonicalOccurrence
     , Text
     , GeneratedProfileEvidenceKind
     , [CanonicalOccurrence]
     , Text
     , [DraftScalar])
defectOrder profileDefect =
  ( profileDefectSubjectValue profileDefect
  , profileDefectRuleIdValue profileDefect
  , profileDefectEvidenceKindValue profileDefect
  , profileDefectEvidenceOccurrences profileDefect
  , profileDefectEvidenceKeyValue profileDefect
  , profileDefectEvidenceScalarsValue profileDefect)

contractFailureOrder ::
     ProfileContractFailure
  -> ( CanonicalOccurrence
     , Text
     , GeneratedProfileEvidenceKind
     , [CanonicalOccurrence]
     , Text
     , [DraftScalar])
contractFailureOrder failure =
  case failure of
    UnknownGeneratedProfileRule rule kind ->
      (contractSubject, rule, kind, [], "", [])
    GeneratedProfileEvidenceMismatch rule kind ->
      (contractSubject, rule, kind, [], "", [])
    MissingCoreContractBinding binding occurrence ->
      ( occurrence
      , binding
      , GeneratedProfileEvidenceClassificationOccurrence
      , []
      , ""
      , [])
    ImpossibleOccurrenceIdentity occurrence details ->
      ( occurrence
      , details
      , GeneratedProfileEvidenceClassificationOccurrence
      , []
      , ""
      , [])

contractSubject :: CanonicalOccurrence
contractSubject = CanonicalOccurrence CanonicalRecordOccurrence 0

recordsIn :: ProfileIndex -> Set CanonicalOccurrence -> [RecordInfo]
recordsIn projectionIndex occurrences =
  mapMaybe (lookupRecord projectionIndex) (Set.toAscList occurrences)

relationshipsIn :: ProfileIndex -> Set CanonicalOccurrence -> [RelationshipInfo]
relationshipsIn projectionIndex occurrences =
  mapMaybe (findRelationship projectionIndex) (Set.toAscList occurrences)

projectCarrier ::
     ProfileIndex
  -> Set CanonicalOccurrence
  -> RecordInfo
  -> ProjectionResult (CarrierProjection, ProfileMappingProvenance)
projectCarrier projectionIndex qualificationProposals record
  | recordInfoFamily record /= ElementFamily = ProjectionResult [] []
  | isJunction record = ProjectionResult [] []
  | recordInfoOccurrence record `Set.member` qualificationProposals =
    ProjectionResult [] []
  | otherwise =
    case ( typeResult
         , assessCommitment
             projectionIndex
             "property:claim-carrier:o2i.commitment"
             occurrence
         , coreOccurrence occurrence) of
      (Right o2iType, Right commitment, Right coreIdentity) ->
        case matchingCarriers element o2iType of
          [mapping] ->
            case ( lookupCoreCarrierCategory
                     (carrierMappingCategoryValue mapping)
                 , lookupCoreO2IType o2iType) of
              (Just category, Just coreType) ->
                ProjectionResult
                  []
                  [ ( carrierProjection
                        coreIdentity
                        category
                        coreType
                        commitment
                    , CarrierMappingProvenance
                        coreIdentity
                        (carrierMappingRuleIdValue mapping)
                        (carrierMappingIdValue mapping))
                  ]
              (categoryResult, coreTypeResult) ->
                ProjectionResult
                  (missingCoreBinding
                     occurrence
                     ("carrier-category:" <> carrierMappingCategoryValue mapping)
                     categoryResult
                     ++ missingCoreBinding
                          occurrence
                          ("o2i-type:" <> o2iType)
                          coreTypeResult)
                  []
          _ ->
            ProjectionResult
              [ contractIssue
                  (MissingCoreContractBinding
                     "unique-generated-carrier-mapping"
                     occurrence)
              ]
              []
      (typeAssessment, commitmentAssessment, identityAssessment) ->
        ProjectionResult
          (resultErrors typeAssessment
             ++ resultErrors commitmentAssessment
             ++ resultErrors identityAssessment)
          []
  where
    occurrence = recordInfoOccurrence record
    element = archiMateElement record
    typeResult =
      singleProjectionValue
        "typed-carrier-type-projection"
        occurrence
        (assessTextProperty
           projectionIndex
           "property:typed-carrier:o2i.type"
           projectType
           occurrence)
    projectType value
      | null (matchingCarriers element value) = Nothing
      | otherwise = Just value

projectRelationship :: ProfileIndex -> RelationshipInfo -> RelationshipResult
projectRelationship projectionIndex relationship
  | contextualizationMatch kind directed label =
    projectContextualization projectionIndex relationship
  | otherwise = projectSemanticRelationship projectionIndex relationship
  where
    kind = relationshipInfoKind relationship
    directed = relationshipInfoDirected relationship
    label = relationshipInfoLabel relationship

projectContextualization ::
     ProfileIndex -> RelationshipInfo -> RelationshipResult
projectContextualization projectionIndex relationship =
  case ( contextualizationMetadataIssues
       , contextualizationCommitment projectionIndex occurrence
       , relationshipEndpoints relationship
       , coreOccurrence occurrence) of
    ([], Right commitment, Right (source, target), Right projectedOccurrence) ->
      case (coreOccurrence source, coreOccurrence target) of
        (Right projectedSource, Right projectedTarget) ->
          RelationshipResult
            []
            []
            [ contextualizationProjection
                projectedOccurrence
                projectedSource
                projectedTarget
                commitment
            ]
            []
        (sourceResult, targetResult) ->
          RelationshipResult
            (resultErrors sourceResult ++ resultErrors targetResult)
            []
            []
            []
    (metadataIssues, commitmentResult, endpointResult, occurrenceResult) ->
      RelationshipResult
        (metadataIssues
           ++ resultErrors commitmentResult
           ++ resultErrors endpointResult
           ++ resultErrors occurrenceResult)
        []
        []
        []
  where
    occurrence = recordInfoOccurrence (relationshipInfoRecord relationship)
    additionalProperties =
      [ propertyInfoOccurrence property
      | property <- propertiesFor projectionIndex occurrence
      , key <- propertyInfoKeys property
      , "o2i." `Text.isPrefixOf` key
      , key /= "o2i.commitment"
      ]
    contextualizationMetadataIssues =
      patternForbiddenIssues
        "contextualization.metadata.additional-properties"
        occurrence
        (not (null additionalProperties))
        (\rule -> metadataOwnerIssue rule occurrence additionalProperties)

contextualizationCommitment ::
     ProfileIndex -> CanonicalOccurrence -> Either [ProfileIssue] Commitment
contextualizationCommitment projectionIndex occurrence =
  case ( patternTextExpectation
           "contextualization.metadata.commitment-cardinality"
           occurrence
       , patternTextsExpectation
           "contextualization.metadata.commitment-value"
           occurrence) of
    (Right (cardinalityRule, "exactly-one"), Right (valueRule, values)) ->
      assess cardinalityRule valueRule values
    (cardinalityResult, valueResult) ->
      Left (resultErrors cardinalityResult ++ resultErrors valueResult)
  where
    assess cardinalityRule valueRule values =
      case propertiesForKey projectionIndex occurrence "o2i.commitment" of
        [property] ->
          case propertyInfoRawValues property of
            [scalar]
              | draftScalarKindValue scalar == DraftText
                  && draftScalarTextValue scalar `elem` values ->
                case draftScalarTextValue scalar of
                  "candidate" -> Right Candidate
                  "asserted" -> Right Asserted
                  _ -> Left [valueIssue valueRule [property]]
              | otherwise -> Left [valueIssue valueRule [property]]
            _ -> Left [cardinalityIssue cardinalityRule [property]]
        properties -> Left [cardinalityIssue cardinalityRule properties]
    cardinalityIssue rule properties =
      propertySlotIssue
        rule
        occurrence
        "o2i.commitment"
        (map propertyInfoOccurrence properties)
    valueIssue rule properties =
      propertySlotIssue
        rule
        occurrence
        "o2i.commitment"
        (map propertyInfoOccurrence properties)

projectSemanticRelationship ::
     ProfileIndex -> RelationshipInfo -> RelationshipResult
projectSemanticRelationship projectionIndex relationship =
  case matchingRelations kind directed label of
    Left _ ->
      RelationshipResult
        [ relationshipIssue
            "graph.committed-relationship.mapping-selection"
            occurrence
        ]
        []
        []
        []
    Right [] ->
      RelationshipResult
        [ relationshipIssue
            "graph.committed-relationship.mapping-selection"
            occurrence
        ]
        []
        []
        []
    Right [mapping] -> projectMappedRelationship mapping
    Right _ ->
      RelationshipResult
        [ relationshipIssue
            "graph.committed-relationship.mapping-selection"
            occurrence
        ]
        []
        []
        []
  where
    record = relationshipInfoRecord relationship
    occurrence = recordInfoOccurrence record
    kind = relationshipInfoKind relationship
    directed = relationshipInfoDirected relationship
    label = relationshipInfoLabel relationship
    projectMappedRelationship mapping =
      case ( relationAttributeIssues mapping record
           , assessCommitment
               projectionIndex
               "property:semantic-relation:o2i.commitment"
               occurrence
           , relationshipEndpoints relationship
           , coreOccurrence occurrence
           , lookupCoreRelationToken (relationMappingTokenValue mapping)) of
        ([], Right commitment, Right (source, target), Right projectedOccurrence, Just token) ->
          case ( lookupRecord projectionIndex source
               , lookupRecord projectionIndex target
               , coreOccurrence source
               , coreOccurrence target) of
            (Just sourceRecord, Just targetRecord, Right projectedSource, Right projectedTarget)
              | relationMappingApplies
                  mapping
                  (archiMateElement sourceRecord)
                  (archiMateElement targetRecord) ->
                RelationshipResult
                  []
                  [ relationProjection
                      projectedOccurrence
                      projectedSource
                      token
                      projectedTarget
                      commitment
                  ]
                  []
                  [ RelationMappingProvenance
                      projectedOccurrence
                      (relationMappingRuleIdValue mapping)
                      (relationMappingIdValue mapping)
                      projectedSource
                      projectedTarget
                  ]
              | otherwise ->
                RelationshipResult
                  [ relationshipIssue
                      "graph.committed-relationship.archimate-applicability"
                      occurrence
                  ]
                  []
                  []
                  []
            (_, _, sourceResult, targetResult) ->
              RelationshipResult
                (resultErrors sourceResult
                   ++ resultErrors targetResult
                   ++ [ relationshipIssue
                        "graph.committed-relationship.mapping-selection"
                        occurrence
                      | null (resultErrors sourceResult)
                          && null (resultErrors targetResult)
                      ])
                []
                []
                []
        (attributeIssues, commitmentResult, endpointResult, occurrenceResult, tokenResult) ->
          RelationshipResult
            (attributeIssues
               ++ resultErrors commitmentResult
               ++ resultErrors endpointResult
               ++ resultErrors occurrenceResult
               ++ case tokenResult of
                    Nothing ->
                      [ contractIssue
                          (MissingCoreContractBinding
                             ("relation-token:"
                                <> relationMappingTokenValue mapping)
                             occurrence)
                      ]
                    Just _ -> [])
            []
            []
            []

relationAttributeIssues :: RelationMapping -> RecordInfo -> [ProfileIssue]
relationAttributeIssues mapping record =
  case relationAttributeRule (relationMappingIdValue mapping) of
    Nothing -> []
    Just rule
      | all isEmptyTextScalar strengths -> []
      | otherwise -> [relationshipIssue rule (recordInfoOccurrence record)]
  where
    strengths = fieldScalars InfluenceStrengthField record

relationAttributeRule :: Text -> Maybe Text
relationAttributeRule mappingId =
  generatedRelationAttributeRule
    =<< find
          ((== mappingId) . generatedRelationMappingId)
          generatedRelationMappings

isEmptyTextScalar :: DraftScalar -> Bool
isEmptyTextScalar scalar =
  draftScalarKindValue scalar == DraftText
    && Text.null (draftScalarTextValue scalar)

relationshipEndpoints ::
     RelationshipInfo
  -> Either [ProfileIssue] (CanonicalOccurrence, CanonicalOccurrence)
relationshipEndpoints relationship =
  case ( relationshipInfoSource relationship
       , relationshipInfoTarget relationship) of
    (Just source, Just target) -> Right (source, target)
    _ ->
      Left
        [ relationshipIssue
            "graph.committed-relationship.mapping-selection"
            occurrence
        ]
  where
    occurrence = recordInfoOccurrence (relationshipInfoRecord relationship)

projectStructured ::
     ProfileIndex
  -> Set CanonicalOccurrence
  -> [RelationshipInfo]
  -> RecordInfo
  -> StructuredResult
projectStructured projectionIndex structuredCarriers segments record =
  case ( structuredValidationIssues
       , commitmentResult
       , completenessResult
       , coreOccurrence occurrence
       , lookupCoreStructuredPropositionFamilyId
           "collective-strategy-realization"
       , lookupCoreStructuredPropositionRoleId
           "collective-strategy-realization.role.participant"
       , lookupCoreStructuredPropositionRoleId
           "collective-strategy-realization.role.target") of
    ([], Right commitment, Right completenessToken, Right projectedOccurrence, Just family, Just participantRole, Just targetRole) ->
      case lookupCoreParticipantCompletenessToken completenessToken of
        Nothing ->
          StructuredResult
            [ contractIssue
                (MissingCoreContractBinding
                   ("participant-completeness:" <> completenessToken)
                   occurrence)
            ]
            []
            []
            []
        Just completeness ->
          case ( projectSegments participantRole targetRole projectedOccurrence
               , structuredConstructionMappings projectedOccurrence commitment) of
            (ProjectionResult issues incidences, ProjectionResult mappingIssues mappings) ->
              StructuredResult
                (issues ++ mappingIssues)
                [ structuredPropositionProjection
                    projectedOccurrence
                    family
                    completeness
                    commitment
                ]
                incidences
                mappings
    (validationIssues, commitmentAssessment, completenessAssessment, occurrenceResult, familyResult, participantRoleResult, targetRoleResult) ->
      StructuredResult
        (validationIssues
           ++ resultErrors commitmentAssessment
           ++ resultErrors completenessAssessment
           ++ resultErrors occurrenceResult
           ++ missingCoreContract
                occurrence
                familyResult
                participantRoleResult
                targetRoleResult)
        []
        []
        []
  where
    occurrence = recordInfoOccurrence record
    typeResult =
      singleProjectionValue
        "structured-carrier-type-projection"
        occurrence
        (assessTextProperty
           projectionIndex
           "property:typed-carrier:o2i.type"
           Just
           occurrence)
    commitmentResult =
      assessCommitment
        projectionIndex
        "property:claim-carrier:o2i.commitment"
        occurrence
    completenessResult =
      singleProjectionValue
        "structured-carrier-completeness-projection"
        occurrence
        (assessTextProperty
           projectionIndex
           ("property:collective-strategy-realization-junction:"
              <> "o2i.participant-completeness")
           Just
           occurrence)
    structuredCarrierIssues =
      structuredAdditionalPropertyIssues
        ++ patternTextIssues
             "collective.carrier.archimate-element"
             occurrence
             (archiMateElement record)
             (`structuredCarrierIssue` occurrence)
        ++ patternTextIssues
             "collective.carrier.junction-type"
             occurrence
             (if isAndJunction record
                then "and"
                else "")
             (`structuredCarrierIssue` occurrence)
    structuredAdditionalPropertyIssues =
      case patternTextsExpectation
             "collective.carrier.additional-properties"
             occurrence of
        Left issues -> issues
        Right (rule, allowedKeys)
          | null
              [ key
              | property <- propertiesFor projectionIndex occurrence
              , key <- propertyInfoKeys property
              , "o2i." `Text.isPrefixOf` key
              , key `notElem` allowedKeys
              ] -> []
          | otherwise -> [structuredCarrierIssue rule occurrence]
    structuredTypeIssues result =
      case result of
        Right actual ->
          patternTextIssues
            "collective.carrier.o2i-type"
            occurrence
            actual
            (`structuredCarrierIssue` occurrence)
        Left _ -> []
    structuredCommitmentIssues result =
      case result of
        Right commitment ->
          patternTextsIssues
            "collective.carrier.commitment-values"
            occurrence
            (commitmentToken commitment)
            (`structuredCarrierIssue` occurrence)
        Left _ -> []
    structuredValidationIssues =
      structuredCarrierIssues
        ++ resultErrors typeResult
        ++ structuredTypeIssues typeResult
        ++ structuredCommitmentIssues commitmentResult
    missingCoreContract subject family participantRole targetRole
      | allPresent family participantRole targetRole = []
      | otherwise =
        concat
          [ missingCoreBinding
              subject
              "structured-family:collective-strategy-realization"
              family
          , missingCoreBinding
              subject
              "structured-role:collective-strategy-realization.role.participant"
              participantRole
          , missingCoreBinding
              subject
              "structured-role:collective-strategy-realization.role.target"
              targetRole
          ]
    allPresent (Just _) (Just _) (Just _) = True
    allPresent _ _ _ = False
    structuredConstructionMappings projectedOccurrence commitment =
      foldMapProjection
        id
        [ patternTextMappingProvenance
            "collective.carrier.category"
            "StructuredProposition"
            "collective-strategy-realization"
            GeneratedProfileEvidenceStructuredCarrierOccurrence
            occurrence
            projectedOccurrence
        , patternTextMappingProvenance
            "collective.carrier.commitment-key"
            "o2i.commitment"
            "collective-strategy-realization"
            GeneratedProfileEvidenceStructuredCarrierOccurrence
            occurrence
            projectedOccurrence
        , patternTextsMappingProvenance
            "collective.carrier.commitment-values"
            (commitmentToken commitment)
            "collective-strategy-realization"
            GeneratedProfileEvidenceStructuredCarrierOccurrence
            occurrence
            projectedOccurrence
        ]
    projectSegments participantRole targetRole projectedOccurrence =
      foldMapProjection
        (projectStructuredSegment
           projectionIndex
           structuredCarriers
           occurrence
           participantRole
           targetRole
           projectedOccurrence)
        segments

commitmentToken :: Commitment -> Text
commitmentToken Candidate = "candidate"
commitmentToken Asserted = "asserted"

projectStructuredSegment ::
     ProfileIndex
  -> Set CanonicalOccurrence
  -> CanonicalOccurrence
  -> CoreStructuredPropositionRoleId
  -> CoreStructuredPropositionRoleId
  -> OccurrenceIdentity
  -> RelationshipInfo
  -> ProjectionResult StructuredIncidenceProjection
projectStructuredSegment projectionIndex structuredCarriers claim participantRole targetRole projectedClaim relationship =
  case chainIssues ++ segmentIssues of
    [] ->
      case (relationshipEndpoints relationship, coreOccurrence occurrence) of
        (Right (source, target), Right projectedOccurrence)
          | target == claim ->
            projectEndpoint projectedOccurrence participantRole source
          | source == claim ->
            projectEndpoint projectedOccurrence targetRole target
          | otherwise ->
            ProjectionResult
              [ contractIssue
                  (MissingCoreContractBinding
                     "structured-incidence-owner"
                     occurrence)
              ]
              []
        (endpointResult, occurrenceResult) ->
          ProjectionResult
            (resultErrors endpointResult ++ resultErrors occurrenceResult)
            []
    issues -> ProjectionResult issues []
  where
    record = relationshipInfoRecord relationship
    occurrence = recordInfoOccurrence record
    o2iProperties =
      [ property
      | property <- propertiesFor projectionIndex occurrence
      , any ("o2i." `Text.isPrefixOf`) (propertyInfoKeys property)
      ]
    incidentClaims = incidentStructuredCarriers structuredCarriers relationship
    chainIssues =
      patternForbiddenIssues
        "collective.junction.chains"
        occurrence
        (length incidentClaims > 1)
        (\rule -> structuredIncidenceIssue rule occurrence incidentClaims)
    segmentIssues =
      patternTextIssues
        "collective.segments.relationship-type"
        occurrence
        (relationshipInfoKind relationship)
        (`relationshipIssue` occurrence)
        ++ patternBooleanIssues
             "collective.segments.directed"
             occurrence
             (relationshipInfoDirected relationship)
             (`relationshipIssue` occurrence)
        ++ patternTextIssues
             "collective.segments.label"
             occurrence
             (either
                (const "")
                id
                (normalizeLabel (relationshipInfoLabel relationship)))
             (`relationshipIssue` occurrence)
        ++ patternForbiddenIssues
             "collective.segments.metadata"
             occurrence
             (not (null o2iProperties))
             (`relationshipIssue` occurrence)
    projectEndpoint projectedOccurrence role endpoint =
      case coreOccurrence endpoint of
        Left defects -> ProjectionResult defects []
        Right projectedEndpoint ->
          ProjectionResult
            []
            [ structuredIncidenceProjection
                projectedOccurrence
                projectedClaim
                role
                projectedEndpoint
            ]

incidentStructuredCarriers ::
     Set CanonicalOccurrence -> RelationshipInfo -> [CanonicalOccurrence]
incidentStructuredCarriers structuredCarriers relationship =
  Set.toAscList
    (Set.fromList
       (mapMaybe
          id
          [ relationshipInfoSource relationship
          , relationshipInfoTarget relationship
          ])
       `Set.intersection` structuredCarriers)

projectQualificationProposal ::
     ProfileIndex
  -> Set CanonicalOccurrence
  -> RecordInfo
  -> ProjectionResult QualificationProjection
projectQualificationProposal projectionIndex qualification record =
  case ( proposalIssues
       , rationaleResult
       , recordInfoIdentity record
       , coreOccurrence occurrence) of
    ([], Right rationale, IdentityResolved _ identifier, Right projectedOccurrence) ->
      case ( foldMapProjection projectReference references
           , qualificationConstructionMappings projectedOccurrence) of
        (ProjectionResult referenceIssues projectedReferences, ProjectionResult mappingIssues mappings) ->
          ProjectionResult
            (referenceIssues ++ mappingIssues)
            [ QualificationProjection
                (QualificationProposal
                   projectedOccurrence
                   identifier
                   rationale
                   sources
                   projectedReferences)
                mappings
                [ ProfileInvariantEvidence
                    generatedQualificationProposalCategoryRule
                    (ProposalCarrierOccurrenceEvidence occurrence)
                , ProfileInvariantEvidence
                    generatedQualificationProposalStableIdentityScopeRule
                    (ProposalCarrierOccurrenceEvidence occurrence)
                ]
            ]
    (issues, rationaleAssessment, identity, occurrenceResult) ->
      ProjectionResult
        (issues
           ++ resultErrors rationaleAssessment
           ++ identityIssues identity
           ++ resultErrors occurrenceResult)
        []
  where
    occurrence = recordInfoOccurrence record
    proposalType =
      singleProjectionValue
        "qualification-proposal-type-projection"
        occurrence
        (assessTextProperty
           projectionIndex
           "property:typed-carrier:o2i.type"
           Just
           occurrence)
    proposalIssues =
      resultErrors proposalType
        ++ case proposalType of
             Right actual ->
               patternTextIssues
                 "qualification.carrier.o2i-type"
                 occurrence
                 actual
                 (`proposalCarrierIssue` occurrence)
             Left _ -> []
        ++ patternTextIssues
             "qualification.carrier.archimate-element"
             occurrence
             (archiMateElement record)
             (`proposalCarrierIssue` occurrence)
        ++ patternForbiddenIssues
             "qualification.carrier.commitment"
             occurrence
             (not (null commitments))
             (`proposalCarrierIssue` occurrence)
        ++ sourceIssues
    commitments = propertiesForKey projectionIndex occurrence "o2i.commitment"
    sourceResult = projectSources projectionIndex occurrence
    sourceIssues = projectionIssues sourceResult
    sources = projectionValues sourceResult
    rationaleResult = assessQualificationRationale record
    references =
      [ relationship
      | relationship <- incidentRelationships projectionIndex occurrence
      , relationshipInfoOccurrence relationship `Set.member` qualification
      , relationshipInfoSource relationship == Just occurrence
          || hasProperty
               projectionIndex
               "o2i.role"
               (recordInfoOccurrence (relationshipInfoRecord relationship))
      ]
    identityIssues identity =
      case identity of
        IdentityResolved _ _ -> []
        _ ->
          [ proposalCarrierIssue
              "qualification.proposal.carrier.stable-identity"
              occurrence
          ]
    qualificationConstructionMappings projectedOccurrence =
      foldMapProjection
        id
        [ patternTextMappingProvenance
            "qualification.carrier.stable-identity"
            "native-concept-identity"
            "need-qualification-proposal"
            GeneratedProfileEvidenceProposalCarrierOccurrence
            occurrence
            projectedOccurrence
        , propertyCardinalityMappingProvenance
            "property:qualification-proposal-assessment:o2i.source"
            occurrence
            projectedOccurrence
        ]
    projectReference relationship =
      projectQualificationReference projectionIndex occurrence relationship

assessQualificationRationale ::
     RecordInfo -> Either [ProfileIssue] (Maybe QualificationRationale)
assessQualificationRationale record =
  case filter
         ((== DocumentationField) . canonicalFieldValue)
         (recordInfoFields record) of
    [] -> Right Nothing
    [field] ->
      case canonicalFieldScalarsValue field of
        [scalar]
          | draftScalarKindValue scalar == DraftText ->
            Right
              (QualificationRationale (canonicalFieldLocationValue field)
                 <$> normalizeTextValue
                       DocumentationNormalization
                       (draftScalarTextValue scalar))
          | otherwise -> Right Nothing
        _ -> Right Nothing
    _ -> Right Nothing

mappingProvenanceOccurrence :: ProfileMappingProvenance -> OccurrenceIdentity
mappingProvenanceOccurrence provenance =
  case provenance of
    CarrierMappingProvenance occurrence _ _ -> occurrence
    RelationMappingProvenance occurrence _ _ _ _ -> occurrence
    ConstructionMappingProvenance occurrence _ _ _ -> occurrence

projectSources ::
     ProfileIndex -> CanonicalOccurrence -> ProjectionResult QualificationSource
projectSources projectionIndex owner =
  case filter
         ((== mappingId) . generatedPropertyRuntimeMappingId)
         generatedPropertyRuntimePlans of
    [plan] ->
      case assessGeneratedProperty projectionIndex Just owner plan of
        ProjectionResult issues values ->
          foldMapProjection projectSource values `appendProjectionIssues` issues
    _ ->
      ProjectionResult
        [ contractIssue
            (MissingCoreContractBinding
               ("generated-property-runtime-plan:" <> mappingId)
               owner)
        ]
        []
  where
    mappingId = "property:qualification-proposal-assessment:o2i.source"
    projectSource (occurrence, value) =
      case coreOccurrence occurrence of
        Right projectedOccurrence ->
          ProjectionResult [] [QualificationSource projectedOccurrence value]
        Left issues -> ProjectionResult issues []

projectQualificationReference ::
     ProfileIndex
  -> CanonicalOccurrence
  -> RelationshipInfo
  -> ProjectionResult QualificationReference
projectQualificationReference projectionIndex proposal relationship =
  case (allIssues, occurrenceResult, roleResult, targetResult) of
    ([], Right projectedOccurrence, Right projectedRole, Right projectedTarget) ->
      ProjectionResult
        []
        [ QualificationReference
            projectedOccurrence
            projectedRole
            projectedTarget
        ]
    _ -> ProjectionResult allIssues []
  where
    record = relationshipInfoRecord relationship
    occurrence = recordInfoOccurrence record
    commitments = propertiesForKey projectionIndex occurrence "o2i.commitment"
    occurrenceResult = coreOccurrence occurrence
    roleResult = qualificationRole projectionIndex occurrence
    targetResult =
      case relationshipInfoTarget relationship of
        Just target -> coreOccurrence target
        Nothing ->
          Left
            [ proposalReferenceIssue
                "qualification.proposal.reference.direction"
                occurrence
                proposal
                []
            ]
    allIssues =
      referenceIssues
        ++ resultErrors occurrenceResult
        ++ resultErrors roleResult
        ++ resultErrors targetResult
    referenceIssues =
      patternTextIssues
        "qualification.reference.role-property"
        occurrence
        (if hasProperty projectionIndex "o2i.role" occurrence
           then "o2i.role"
           else "")
        (\rule -> proposalReferenceIssue rule occurrence proposal [])
        ++ patternTextIssues
             "qualification.reference.relationship-type"
             occurrence
             (relationshipInfoKind relationship)
             (\rule ->
                proposalReferenceIssue
                  rule
                  occurrence
                  proposal
                  (mapMaybe id [relationshipInfoTarget relationship]))
        ++ patternBooleanIssues
             "qualification.reference.directed"
             occurrence
             (relationshipInfoDirected relationship)
             (\rule ->
                proposalReferenceIssue
                  rule
                  occurrence
                  proposal
                  (mapMaybe id [relationshipInfoTarget relationship]))
        ++ patternTextIssues
             "qualification.reference.direction"
             occurrence
             (if relationshipInfoSource relationship == Just proposal
                then "proposal-to-subject"
                else "")
             (\rule ->
                proposalReferenceIssue
                  rule
                  occurrence
                  proposal
                  (mapMaybe id [relationshipInfoTarget relationship]))
        ++ patternForbiddenIssues
             "qualification.reference.commitment"
             occurrence
             (not (null commitments))
             (\rule ->
                proposalReferenceIssue
                  rule
                  occurrence
                  proposal
                  (map propertyInfoOccurrence commitments))

isStructuredCandidate :: ProfileIndex -> RecordInfo -> Bool
isStructuredCandidate projectionIndex record =
  recordInfoFamily record == ElementFamily
    && (hasExactType "collective.carrier.o2i-type"
          || (isJunction record
                && any
                     (\key -> hasProperty projectionIndex key occurrence)
                     [ "o2i.type"
                     , "o2i.commitment"
                     , "o2i.participant-completeness"
                     ]))
  where
    occurrence = recordInfoOccurrence record
    hasExactType subject =
      maybe
        False
        (`elem` propertyTextValues projectionIndex occurrence "o2i.type")
        (patternExpectationValue PatternTextExpectation subject)

reservedNamespaceIssues ::
     ProfileIndex
  -> Set CanonicalOccurrence
  -> Set CanonicalOccurrence
  -> [ProfileIssue]
reservedNamespaceIssues projectionIndex qualificationProposals universe =
  concatMap
    assess
    (mapMaybe
       (`Map.lookup` indexPropertyByOccurrence projectionIndex)
       (Set.toAscList universe))
  where
    knownKeys =
      [ "o2i.profile"
      , "o2i.type"
      , "o2i.commitment"
      , "o2i.participant-completeness"
      , "o2i.source"
      , "o2i.role"
      ]
    assess property =
      [ if key `elem` knownKeys
        then reservedPropertyIssue ("reserved-placement:" <> key) property key
        else classificationIssue
               "classification.shared.activate.unknown-property"
               (propertyInfoOwner property)
      | key <- propertyInfoKeys property
      , "o2i." `Text.isPrefixOf` key
      , key
          `notElem` allowedReservedKeys
                      projectionIndex
                      qualificationProposals
                      property
      ]

allowedReservedKeys ::
     ProfileIndex -> Set CanonicalOccurrence -> PropertyInfo -> [Text]
allowedReservedKeys projectionIndex qualificationProposals property =
  case Map.lookup (propertyInfoOwner property) (indexRecords projectionIndex) of
    Nothing -> []
    Just record ->
      case recordInfoFamily record of
        ModelRootFamily -> ["o2i.profile"]
        ElementFamily
          | recordInfoOccurrence record `Set.member` qualificationProposals ->
            ["o2i.type", "o2i.source"]
          | isJunction record ->
            ["o2i.type", "o2i.commitment", "o2i.participant-completeness"]
          | otherwise -> ["o2i.type", "o2i.commitment"]
        RelationshipFamily ->
          case findRelationship projectionIndex (recordInfoOccurrence record) of
            Just relationship
              | isQualificationReferenceCandidate
                  qualificationProposals
                  relationship -> ["o2i.role"]
              | structuredSegmentMatch
                  (relationshipInfoKind relationship)
                  (relationshipInfoDirected relationship)
                  (relationshipInfoLabel relationship) -> []
              | otherwise -> ["o2i.commitment"]
            Nothing -> []
        _ -> []

findRelationship ::
     ProfileIndex -> CanonicalOccurrence -> Maybe RelationshipInfo
findRelationship projectionIndex occurrence =
  Map.lookup occurrence (indexRelationships projectionIndex)

isQualificationReferenceCandidate ::
     Set CanonicalOccurrence -> RelationshipInfo -> Bool
isQualificationReferenceCandidate qualificationProposals relationship =
  maybe
    False
    (`Set.member` qualificationProposals)
    (relationshipInfoSource relationship)

assessTextProperty ::
     ProfileIndex
  -> Text
  -> (Text -> Maybe Text)
  -> CanonicalOccurrence
  -> ProjectionResult Text
assessTextProperty projectionIndex mappingId domainProjection owner =
  case filter
         ((== mappingId) . generatedPropertyRuntimeMappingId)
         generatedPropertyRuntimePlans of
    [plan] ->
      mapProjectionValues
        snd
        (assessGeneratedProperty projectionIndex domainProjection owner plan)
    _ ->
      ProjectionResult
        [ contractIssue
            (MissingCoreContractBinding
               ("generated-property-runtime-plan:" <> mappingId)
               owner)
        ]
        []

assessGeneratedProperty ::
     ProfileIndex
  -> (Text -> Maybe Text)
  -> CanonicalOccurrence
  -> GeneratedPropertyRuntimePlan
  -> ProjectionResult (CanonicalOccurrence, Text)
assessGeneratedProperty projectionIndex domainProjection owner plan =
  foldMapProjection assessOccurrence properties
    `appendProjectionIssues` propertyCardinalityIssues
  where
    key = generatedPropertyRuntimeKey plan
    properties = propertiesForKey projectionIndex owner key
    propertyCardinalityIssues =
      [ propertySlotIssue
        (generatedPropertyRuntimePropertyCardinalityRuleId plan)
        owner
        key
        (map propertyInfoOccurrence properties)
      | not
          (cardinalitySatisfied
             (generatedPropertyRuntimePropertyCardinality plan)
             (length properties))
      ]
    assessOccurrence property =
      foldMapProjection assessScalar scalars
        `appendProjectionIssues` valueCardinalityIssues
      where
        scalars = propertyInfoRawValues property
        valueCardinalityIssues =
          [ propertyOccurrenceIssue
            (generatedPropertyRuntimeValueCardinalityRuleId plan)
            (propertyInfoOccurrence property)
            owner
          | not
              (cardinalitySatisfied
                 (generatedPropertyRuntimeValueCardinality plan)
                 (length scalars))
          ]
        assessScalar scalar
          | draftScalarKindValue scalar /= DraftText =
            ProjectionResult
              [ propertyValueIssueFor
                  (generatedPropertyRuntimeValueKindRuleId plan)
                  property
                  scalar
              ]
              []
          | otherwise =
            case applyPropertyConstraint
                   domainProjection
                   (generatedPropertyRuntimeConstraint plan)
                   (draftScalarTextValue scalar) of
              Left () ->
                ProjectionResult
                  [ contractIssue
                      (MissingCoreContractBinding
                         ("generated-property-runtime-constraint:"
                            <> generatedPropertyRuntimeMappingId plan)
                         (propertyInfoOccurrence property))
                  ]
                  []
              Right Nothing ->
                ProjectionResult
                  [ propertyValueIssueFor
                      (propertyConstraintRuleId plan)
                      property
                      scalar
                  ]
                  []
              Right (Just value) ->
                ProjectionResult [] [(propertyInfoOccurrence property, value)]

applyPropertyConstraint ::
     (Text -> Maybe Text)
  -> GeneratedPropertyConstraint
  -> Text
  -> Either () (Maybe Text)
applyPropertyConstraint domainProjection constraint value =
  case constraint of
    GeneratedAdmittedValuesConstraint _ expected ->
      fmap
        (\matches ->
           if matches
             then Just value
             else Nothing)
        (matchesGeneratedText value expected)
    GeneratedDomainConstraint _ expected ->
      case expected of
        GeneratedExpectedText _ -> Right (domainProjection value)
        _ -> Left ()
    GeneratedGrammarConstraint _ expected ->
      case expected of
        GeneratedExpectedText _ -> Right (normalizeSourceIdentity value)
        _ -> Left ()

propertyConstraintRuleId :: GeneratedPropertyRuntimePlan -> Text
propertyConstraintRuleId plan =
  case generatedPropertyRuntimeConstraint plan of
    GeneratedAdmittedValuesConstraint rule _ -> rule
    GeneratedDomainConstraint rule _ -> rule
    GeneratedGrammarConstraint rule _ -> rule

cardinalitySatisfied :: GeneratedCardinalityExpectation -> Int -> Bool
cardinalitySatisfied expectation count =
  case expectation of
    GeneratedExactlyOne -> count == 1
    GeneratedZeroOrMany -> True

appendProjectionIssues ::
     ProjectionResult value -> [ProfileIssue] -> ProjectionResult value
appendProjectionIssues result issues =
  result {projectionIssues = issues ++ projectionIssues result}

mapProjectionValues ::
     (source -> target) -> ProjectionResult source -> ProjectionResult target
mapProjectionValues project result =
  ProjectionResult
    (projectionIssues result)
    (map project (projectionValues result))

singleProjectionValue ::
     Text
  -> CanonicalOccurrence
  -> ProjectionResult value
  -> Either [ProfileIssue] value
singleProjectionValue binding occurrence result =
  case (projectionIssues result, projectionValues result) of
    ([], [value]) -> Right value
    (issues@(_:_), _) -> Left issues
    _ -> Left [contractIssue (MissingCoreContractBinding binding occurrence)]

assessCommitment ::
     ProfileIndex
  -> Text
  -> CanonicalOccurrence
  -> Either [ProfileIssue] Commitment
assessCommitment projectionIndex mappingId occurrence = do
  value <-
    singleProjectionValue
      ("commitment-projection:" <> mappingId)
      occurrence
      (assessTextProperty projectionIndex mappingId Just occurrence)
  case value of
    "candidate" -> Right Candidate
    "asserted" -> Right Asserted
    _ ->
      Left
        [ contractIssue
            (MissingCoreContractBinding
               ("commitment-value:" <> mappingId)
               occurrence)
        ]

matchesGeneratedText :: Text -> GeneratedRuntimeExpected -> Either () Bool
matchesGeneratedText actual expected =
  case expected of
    GeneratedExpectedText value -> Right (actual == value)
    GeneratedExpectedTexts values -> Right (actual `elem` values)
    GeneratedExpectedBoolean _ -> Left ()

-- /normalizationContract defines both modes and source-identity delegation.
normalizeTextValue :: TextNormalization -> Text -> Maybe Text
normalizeTextValue normalization raw
  | Text.any isNonScalar raw = Nothing
  | Text.any (rejectedControl normalization) lineNormalized = Nothing
  | normalization == NonEmptyScalarNormalization && Text.any (== '\t') trimmed =
    Nothing
  | Text.null trimmed = Nothing
  | otherwise = Just trimmed
  where
    lineNormalized =
      case normalization of
        DocumentationNormalization ->
          Text.replace "\r" "\n" (Text.replace "\r\n" "\n" raw)
        NonEmptyScalarNormalization -> raw
    normalized = normalize NFC lineNormalized
    trimmed = Text.dropAround (edgeWhitespace normalization) normalized

normalizeSourceIdentity :: Text -> Maybe Text
normalizeSourceIdentity raw = do
  normalized <- normalizeTextValue NonEmptyScalarNormalization raw
  case modelIdentity normalized of
    Left _ -> Nothing
    Right _ -> Just normalized

edgeWhitespace :: TextNormalization -> Char -> Bool
edgeWhitespace normalization character =
  character == '\t'
    || character == ' '
    || (normalization == DocumentationNormalization && character == '\n')

rejectedControl :: TextNormalization -> Char -> Bool
rejectedControl normalization character =
  let codepoint = ord character
   in (codepoint >= 0x00 && codepoint <= 0x08)
        || (codepoint >= 0x0B && codepoint <= 0x1F)
        || codepoint == 0x7F
        || (normalization == NonEmptyScalarNormalization && character == '\n')

isNonScalar :: Char -> Bool
isNonScalar character =
  let codepoint = ord character
   in codepoint >= 0xD800 && codepoint <= 0xDFFF

propertyTextValues :: ProfileIndex -> CanonicalOccurrence -> Text -> [Text]
propertyTextValues projectionIndex occurrence key =
  [ draftScalarTextValue scalar
  | property <- propertiesForKey projectionIndex occurrence key
  , scalar <- propertyInfoRawValues property
  , draftScalarKindValue scalar == DraftText
  ]

fieldScalars :: DraftFieldValue -> RecordInfo -> [DraftScalar]
fieldScalars field record =
  [ scalar
  | canonicalField <- recordInfoFields record
  , canonicalFieldValue canonicalField == field
  , scalar <- canonicalFieldScalarsValue canonicalField
  ]

fieldTextValues :: DraftFieldValue -> RecordInfo -> [Text]
fieldTextValues field = fieldTextValuesFromFields field . recordInfoFields

fieldTextValuesFromFields :: DraftFieldValue -> [CanonicalField] -> [Text]
fieldTextValuesFromFields field fields =
  [ draftScalarTextValue scalar
  | canonicalField <- fields
  , canonicalFieldValue canonicalField == field
  , scalar <- canonicalFieldScalarsValue canonicalField
  , draftScalarKindValue scalar == DraftText
  ]

coreOccurrence ::
     CanonicalOccurrence -> Either [ProfileIssue] OccurrenceIdentity
coreOccurrence occurrence =
  case canonicalOccurrenceIdentityValue occurrence of
    Right identity -> Right identity
    Left identityDefect ->
      Left
        [ contractIssue
            (ImpossibleOccurrenceIdentity
               occurrence
               (Text.pack (show identityDefect)))
        ]

canonicalOccurrenceIdentityValue ::
     CanonicalOccurrence -> Either OccurrenceIdentityDefect OccurrenceIdentity
canonicalOccurrenceIdentityValue occurrence =
  occurrenceIdentity
    ("archimate:"
       <> occurrenceKindToken (canonicalOccurrenceKindValue occurrence)
       <> ":"
       <> Text.pack (show (canonicalOccurrenceOrdinalValue occurrence)))

occurrenceKindToken :: CanonicalOccurrenceKind -> Text
occurrenceKindToken kind =
  case kind of
    CanonicalRecordOccurrence -> "record"
    CanonicalPropertyOccurrence -> "property"
    CanonicalReferenceOccurrence -> "reference"

profileDefectRuleIdValue :: ProfileDefect -> Text
profileDefectRuleIdValue (ProfileDefect rule _) =
  generatedProfileDefectRuleId rule

profileDefectSubjectValue :: ProfileDefect -> CanonicalOccurrence
profileDefectSubjectValue (ProfileDefect _ evidence) =
  case evidence of
    ClassificationOccurrenceEvidence occurrence -> occurrence
    MetadataOwnerAndO2iPropertyOccurrencesEvidence owner _ -> owner
    PropertyOccurrenceEvidence property _ -> property
    PropertySlotEvidence owner _ _ -> owner
    PropertyValueEvidence property _ _ -> property
    ProposalCarrierOccurrenceEvidence occurrence -> occurrence
    ProposalReferenceIncidenceEvidence occurrence _ _ -> occurrence
    RelationshipOccurrenceEvidence occurrence -> occurrence
    ReservedPropertyOccurrenceEvidence property _ _ -> property
    StructuredCarrierOccurrenceEvidence occurrence -> occurrence
    StructuredIncidenceEvidence occurrence _ -> occurrence

profileDefectEvidenceOccurrences :: ProfileDefect -> [CanonicalOccurrence]
profileDefectEvidenceOccurrences (ProfileDefect _ evidence) =
  case evidence of
    ClassificationOccurrenceEvidence occurrence -> [occurrence]
    MetadataOwnerAndO2iPropertyOccurrencesEvidence owner properties ->
      owner : properties
    PropertyOccurrenceEvidence property owner -> [property, owner]
    PropertySlotEvidence owner _ properties -> owner : properties
    PropertyValueEvidence property owner _ -> [property, owner]
    ProposalCarrierOccurrenceEvidence occurrence -> [occurrence]
    ProposalReferenceIncidenceEvidence occurrence proposal related ->
      occurrence : proposal : related
    RelationshipOccurrenceEvidence occurrence -> [occurrence]
    ReservedPropertyOccurrenceEvidence property owner _ -> [property, owner]
    StructuredCarrierOccurrenceEvidence occurrence -> [occurrence]
    StructuredIncidenceEvidence occurrence related -> occurrence : related

profileDefectEvidenceKindValue :: ProfileDefect -> GeneratedProfileEvidenceKind
profileDefectEvidenceKindValue (ProfileDefect _ evidence) =
  profileEvidenceKind evidence

profileDefectEvidenceKeyValue :: ProfileDefect -> Text
profileDefectEvidenceKeyValue (ProfileDefect _ evidence) =
  case evidence of
    PropertySlotEvidence _ key _ -> key
    ReservedPropertyOccurrenceEvidence _ _ key -> key
    _ -> ""

profileDefectEvidenceScalarsValue :: ProfileDefect -> [DraftScalar]
profileDefectEvidenceScalarsValue (ProfileDefect _ evidence) =
  case evidence of
    PropertyValueEvidence _ _ scalars -> scalars
    _ -> []

profileEvidenceKind :: ProfileEvidence kind -> GeneratedProfileEvidenceKind
profileEvidenceKind evidence =
  case evidence of
    CarrierOccurrenceEvidence _ -> GeneratedProfileEvidenceCarrierOccurrence
    ClassificationOccurrenceEvidence _ ->
      GeneratedProfileEvidenceClassificationOccurrence
    MetadataOwnerAndO2iPropertyOccurrencesEvidence _ _ ->
      GeneratedProfileEvidenceMetadataOwnerAndO2iPropertyOccurrences
    PropertyOccurrenceEvidence _ _ ->
      GeneratedProfileEvidencePropertyOccurrenceEvidence
    PropertySlotEvidence _ _ _ -> GeneratedProfileEvidencePropertySlotEvidence
    PropertyValueEvidence _ _ _ -> GeneratedProfileEvidencePropertyValueEvidence
    ProposalCarrierOccurrenceEvidence _ ->
      GeneratedProfileEvidenceProposalCarrierOccurrence
    ProposalReferenceIncidenceEvidence _ _ _ ->
      GeneratedProfileEvidenceProposalReferenceIncidence
    RelationshipOccurrenceEvidence _ ->
      GeneratedProfileEvidenceRelationshipOccurrence
    ReservedPropertyOccurrenceEvidence _ _ _ ->
      GeneratedProfileEvidenceReservedPropertyOccurrence
    StructuredCarrierOccurrenceEvidence _ ->
      GeneratedProfileEvidenceStructuredCarrierOccurrence
    StructuredIncidenceEvidence _ _ ->
      GeneratedProfileEvidenceStructuredIncidence

generatedRuleForEvidence ::
     ProfileEvidence kind -> Text -> Maybe (GeneratedProfileDefectRule kind)
generatedRuleForEvidence evidence rule =
  case evidence of
    CarrierOccurrenceEvidence _ -> generatedCarrierOccurrenceDefectRule rule
    ClassificationOccurrenceEvidence _ ->
      generatedClassificationOccurrenceDefectRule rule
    MetadataOwnerAndO2iPropertyOccurrencesEvidence _ _ ->
      generatedMetadataOwnerAndO2iPropertyOccurrencesDefectRule rule
    PropertyOccurrenceEvidence _ _ ->
      generatedPropertyOccurrenceEvidenceDefectRule rule
    PropertySlotEvidence _ _ _ -> generatedPropertySlotEvidenceDefectRule rule
    PropertyValueEvidence _ _ _ -> generatedPropertyValueEvidenceDefectRule rule
    ProposalCarrierOccurrenceEvidence _ ->
      generatedProposalCarrierOccurrenceDefectRule rule
    ProposalReferenceIncidenceEvidence _ _ _ ->
      generatedProposalReferenceIncidenceDefectRule rule
    RelationshipOccurrenceEvidence _ ->
      generatedRelationshipOccurrenceDefectRule rule
    ReservedPropertyOccurrenceEvidence _ _ _ ->
      generatedReservedPropertyOccurrenceDefectRule rule
    StructuredCarrierOccurrenceEvidence _ ->
      generatedStructuredCarrierOccurrenceDefectRule rule
    StructuredIncidenceEvidence _ _ ->
      generatedStructuredIncidenceDefectRule rule

modelIssue :: Text -> ProfileEvidence kind -> ProfileIssue
modelIssue rule evidence =
  case generatedRuleForEvidence evidence rule of
    Just generatedRule ->
      ProfileModelDefect (ProfileDefect generatedRule evidence)
    Nothing
      | rule `elem` generatedProfileRuleIds ->
        contractIssue
          (GeneratedProfileEvidenceMismatch rule (profileEvidenceKind evidence))
      | otherwise ->
        contractIssue
          (UnknownGeneratedProfileRule rule (profileEvidenceKind evidence))

contractIssue :: ProfileContractFailure -> ProfileIssue
contractIssue = ProfileContractFailure

missingCoreBinding ::
     CanonicalOccurrence -> Text -> Maybe value -> [ProfileIssue]
missingCoreBinding occurrence binding result =
  case result of
    Just _ -> []
    Nothing -> [contractIssue (MissingCoreContractBinding binding occurrence)]

classificationIssue :: Text -> CanonicalOccurrence -> ProfileIssue
classificationIssue rule occurrence =
  modelIssue rule (ClassificationOccurrenceEvidence occurrence)

propertyOccurrenceIssue ::
     Text -> CanonicalOccurrence -> CanonicalOccurrence -> ProfileIssue
propertyOccurrenceIssue rule property owner =
  modelIssue rule (PropertyOccurrenceEvidence property owner)

propertySlotIssue ::
     Text
  -> CanonicalOccurrence
  -> Text
  -> [CanonicalOccurrence]
  -> ProfileIssue
propertySlotIssue rule owner key properties =
  modelIssue rule (PropertySlotEvidence owner key properties)

propertyValueIssueFor :: Text -> PropertyInfo -> DraftScalar -> ProfileIssue
propertyValueIssueFor rule property scalar =
  modelIssue
    rule
    (PropertyValueEvidence
       (propertyInfoOccurrence property)
       (propertyInfoOwner property)
       [scalar])

metadataOwnerIssue ::
     Text -> CanonicalOccurrence -> [CanonicalOccurrence] -> ProfileIssue
metadataOwnerIssue rule owner properties =
  modelIssue
    rule
    (MetadataOwnerAndO2iPropertyOccurrencesEvidence owner properties)

proposalCarrierIssue :: Text -> CanonicalOccurrence -> ProfileIssue
proposalCarrierIssue rule occurrence =
  modelIssue rule (ProposalCarrierOccurrenceEvidence occurrence)

proposalReferenceIssue ::
     Text
  -> CanonicalOccurrence
  -> CanonicalOccurrence
  -> [CanonicalOccurrence]
  -> ProfileIssue
proposalReferenceIssue rule occurrence proposal related =
  modelIssue
    rule
    (ProposalReferenceIncidenceEvidence occurrence proposal related)

relationshipIssue :: Text -> CanonicalOccurrence -> ProfileIssue
relationshipIssue rule occurrence =
  modelIssue rule (RelationshipOccurrenceEvidence occurrence)

reservedPropertyIssue :: Text -> PropertyInfo -> Text -> ProfileIssue
reservedPropertyIssue rule property key =
  modelIssue
    rule
    (ReservedPropertyOccurrenceEvidence
       (propertyInfoOccurrence property)
       (propertyInfoOwner property)
       key)

structuredCarrierIssue :: Text -> CanonicalOccurrence -> ProfileIssue
structuredCarrierIssue rule occurrence =
  modelIssue rule (StructuredCarrierOccurrenceEvidence occurrence)

structuredIncidenceIssue ::
     Text -> CanonicalOccurrence -> [CanonicalOccurrence] -> ProfileIssue
structuredIncidenceIssue rule occurrence related =
  modelIssue rule (StructuredIncidenceEvidence occurrence related)

qualificationRole ::
     ProfileIndex
  -> CanonicalOccurrence
  -> Either [ProfileIssue] CoreQualificationProposalRoleId
qualificationRole projectionIndex occurrence = do
  role <-
    singleProjectionValue
      "qualification-reference-role-projection"
      occurrence
      (assessTextProperty
         projectionIndex
         "property:qualification-proposal-reference-association:o2i.role"
         Just
         occurrence)
  case lookupCoreQualificationProposalRoleId
         ("need-qualification-proposal.role." <> role) of
    Just coreRole -> Right coreRole
    Nothing ->
      Left
        [ contractIssue
            (MissingCoreContractBinding
               ("qualification-role:" <> role)
               occurrence)
        ]

resultErrors :: Either [ProfileIssue] value -> [ProfileIssue]
resultErrors = either id (const [])

foldMapProjection ::
     (input -> ProjectionResult output) -> [input] -> ProjectionResult output
foldMapProjection project = foldr append (ProjectionResult [] [])
  where
    append input accumulated =
      case project input of
        ProjectionResult issues values ->
          ProjectionResult
            (issues ++ projectionIssues accumulated)
            (values ++ projectionValues accumulated)
