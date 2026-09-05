{-# LANGUAGE OverloadedStrings #-}

-- | Capability-neutral canonical fragments shared by Operation reports.
module O2I.Operation.Machine.Fragment.Internal
  ( acquisitionFailureFragment
  , adapterDescriptorFragment
  , adapterDiagnosticFragment
  , adapterSelectionErrorFragment
  , sourceIdentityFragment
  , draftLocationFragment
  , draftValueKindFragment
  , draftScalarFragment
  , canonicalOccurrenceFragment
  , preparedDiagnosticDocumentFragment
  , foldPreparedDiagnosticDocumentFragments
  , emptySupplementalDiagnosticGroupFragments
  , viewDescriptorFragment
  ) where

import Control.Exception (IOException, displayException)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile.Closure as Closure
import O2I.ArchiMate.Profile.Draft
  ( DraftFieldValue
  , DraftLocation
  , DraftNativeName
  , DraftPathStep
  , DraftScalar
  , DraftSourcePosition
  , DraftSourceSpan
  , DraftValueKind
  , draftLocationPath
  , draftLocationSpan
  , draftNativeLocalName
  , draftNativeNamespace
  , draftPathStepName
  , draftPathStepOrdinal
  , draftScalarLocation
  , draftSourceColumn
  , draftSourceLine
  , draftSourceOffset
  , draftSpanEnd
  , draftSpanStart
  , foldDraftFieldValue
  , foldDraftScalarValue
  , foldDraftSourcePath
  , foldDraftValueKind
  )
import O2I.ArchiMate.Profile.Notation
  ( ArchiMateNotationEvidence
  , ArchiMateNotationIssueKind
  , CanonicalField
  , CanonicalOccurrence
  , CanonicalView
  , IdentityInvalidReason
  , IdentityOutcome
  , allArchiMateNotationIssueKinds
  , archiMateNotationIssueEvidence
  , archiMateNotationIssueKind
  , archiMateNotationIssueKindToken
  , archiMateNotationIssueSubject
  , canonicalFieldKind
  , canonicalFieldLocation
  , canonicalFieldScalars
  , canonicalOccurrenceKind
  , canonicalOccurrenceOrdinal
  , canonicalViewIdentity
  , canonicalViewLocation
  , canonicalViewNameFields
  , canonicalViewOccurrence
  , foldArchiMateNotationEvidence
  , foldCanonicalOccurrenceKind
  , foldIdentityInvalidReason
  , foldIdentityOutcome
  )
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.ArchiMate.Profile.Resolution
  ( ProfileDescriptor
  , foldProfileDescriptor
  )
import O2I.Core.Contract (coreRuleIdText)
import O2I.Core.Identity
  ( ModelIdentity
  , OccurrenceIdentity
  , modelIdentityText
  , occurrenceIdentityText
  )
import O2I.Operation.Acquisition
  ( AcquiredSupplementalSource
  , AcquisitionFailure
  , acquiredSourceIdentity
  , foldAcquiredSupplementalSource
  , foldAcquisitionFailure
  , foldInputSource
  )
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterDiagnostic
  , AdapterOccurrence
  , AdapterRule
  , AdapterSelectionError
  , CompiledAdapterContract
  , NativeLocation
  , adapterContractDescriptor
  , adapterDescriptorId
  , adapterDescriptorName
  , adapterDescriptorNotation
  , adapterDescriptorVersion
  , adapterDiagnosticOccurrences
  , adapterDiagnosticRule
  , adapterIdText
  , adapterRuleAction
  , adapterRuleExpectation
  , adapterRuleId
  , adapterRuleIdText
  , adapterRuleMeaning
  , adapterRuleStage
  , adapterRuleStageText
  , foldAdapterOccurrence
  , foldAdapterSelectionError
  , foldNativeLocation
  , lookupArchiMateNotationRule
  )
import O2I.Operation.Diagnostic
  ( PreparedDiagnostic
  , PreparedDiagnosticDocument
  , diagnosticDispositionText
  , diagnosticSeverityText
  , foldPreparedDiagnostic
  , foldPreparedDiagnosticDocument
  , preparedDiagnosticDisposition
  , preparedDiagnosticOwner
  , preparedDiagnosticProducer
  , preparedDiagnosticRuleIdentity
  , preparedDiagnosticSeverity
  , preparedDiagnosticStage
  , processFailure
  )
import O2I.Operation.Diagnostic.AdapterOwner.Internal
  ( foldAdapterNotationDiagnostic
  )
import O2I.Operation.Diagnostic.Internal
  ( SupplementalDiagnosticGroup(..)
  , SupplementalDiagnosticGroups(..)
  )
import O2I.Operation.Diagnostic.Owner.Source.Internal
  ( PreparedAuthority(..)
  , SupplementalOwnerBindingEvidence(..)
  )
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , CanonicalMember
  , arrayFragment
  , booleanFragment
  , closedObjectFragment
  , naturalFragment
  , nullFragment
  , requiredMember
  , textFragment
  )
import O2I.Operation.Provenance
  ( SourceIdentity
  , SourceRole(..)
  , foldSourceIdentity
  , sourceIdentityOrdinal
  , sourceIdentityReference
  , sourceIdentitySha256
  , sourceOrdinalValue
  , sourceReferenceText
  , sourceSha256Text
  )
import qualified O2I.Semantics as Semantics
import qualified O2I.Semantics.Input as Binding
import qualified O2I.Structure as Structure

adapterDescriptorFragment :: AdapterDescriptor -> CanonicalFragment
adapterDescriptorFragment descriptor =
  closedObjectFragment
    [ requiredMember
        "id"
        (textFragment (adapterIdText (adapterDescriptorId descriptor)))
    , requiredMember "name" (textFragment (adapterDescriptorName descriptor))
    , requiredMember
        "version"
        (textFragment (adapterDescriptorVersion descriptor))
    , requiredMember
        "notation"
        (textFragment (adapterDescriptorNotation descriptor))
    ]

adapterDiagnosticFragment :: AdapterDiagnostic -> CanonicalFragment
adapterDiagnosticFragment diagnostic =
  closedObjectFragment
    [ requiredMember
        "rule"
        (adapterRuleFragment (adapterDiagnosticRule diagnostic))
    , requiredMember
        "occurrences"
        (arrayFragment
           (fmap
              adapterOccurrenceFragment
              (NonEmpty.toList (adapterDiagnosticOccurrences diagnostic))))
    ]

adapterSelectionErrorFragment :: AdapterSelectionError -> CanonicalFragment
adapterSelectionErrorFragment =
  foldAdapterSelectionError
    (\identifier ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "unknown-adapter")
         , requiredMember "adapterId" (textFragment (adapterIdText identifier))
         ])
    (\failures ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "recognition-failed")
         , requiredMember
             "failures"
             (arrayFragment
                [ closedObjectFragment
                  [ requiredMember "adapter" (adapterDescriptorFragment adapter)
                  , requiredMember
                      "diagnostics"
                      (arrayFragment
                         (fmap
                            adapterDiagnosticFragment
                            (NonEmpty.toList diagnostics)))
                  ]
                | (adapter, diagnostics) <- NonEmpty.toList failures
                ])
         ])
    (closedObjectFragment [requiredMember "kind" (textFragment "no-match")])
    (\descriptors ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "multiple-matches")
         , requiredMember
             "adapters"
             (arrayFragment
                (fmap adapterDescriptorFragment (NonEmpty.toList descriptors)))
         ])

acquisitionFailureFragment :: AcquisitionFailure -> CanonicalFragment
acquisitionFailureFragment =
  foldAcquisitionFailure $ \source exception ->
    foldInputSource
      (\reference _ ->
         sourceFailureFragment "file" (sourceReferenceText reference) exception)
      (\reference ->
         sourceFailureFragment "stdin" (sourceReferenceText reference) exception)
      source

sourceIdentityFragment :: SourceIdentity -> CanonicalFragment
sourceIdentityFragment =
  foldSourceIdentity $ \role ordinal reference digest ->
    closedObjectFragment
      [ requiredMember "role" (textFragment (sourceRoleText role))
      , requiredMember "ordinal" (naturalFragment (sourceOrdinalValue ordinal))
      , requiredMember
          "reference"
          (textFragment (sourceReferenceText reference))
      , requiredMember "sha256" (textFragment (sourceSha256Text digest))
      ]

-- | Encode one authority-once prepared diagnostic document.
preparedDiagnosticDocumentFragment ::
     PreparedDiagnosticDocument -> CanonicalFragment
preparedDiagnosticDocumentFragment =
  foldPreparedDiagnosticDocument $ \authority diagnostics groups ->
    case groups of
      SupplementalDiagnosticGroups supplementalGroups ->
        closedObjectFragment
          [ requiredMember "schema" (textFragment "o2i.operation.diagnostic/v2")
          , requiredMember "authority" (preparedAuthorityFragment authority)
          , requiredMember
              "modelDiagnostics"
              (arrayFragment (map preparedDiagnosticFragment diagnostics))
          , requiredMember
              "supplementalSources"
              (closedObjectFragment
                 (map supplementalGroupMember supplementalGroups))
          ]

-- | Project exactly one sealed common diagnostic document into the three
-- authority-correlated fragment sequences needed by capability envelopes.
-- Supplemental entries retain their canonical group order and deliberately
-- carry no ordinal field: an enclosing array position is their sole ordinal.
foldPreparedDiagnosticDocumentFragments ::
     (CanonicalFragment -> [CanonicalFragment] -> [CanonicalFragment] -> result)
  -> PreparedDiagnosticDocument
  -> result
foldPreparedDiagnosticDocumentFragments consume =
  foldPreparedDiagnosticDocument $ \authority diagnostics groups ->
    case groups of
      SupplementalDiagnosticGroups supplementalGroups ->
        consume
          (preparedAuthorityFragment authority)
          (map preparedDiagnosticFragment diagnostics)
          (map supplementalGroupFragment supplementalGroups)

-- | Project already acquired pre-Binding sources through the same ordered
-- array-entry form, with an exact empty diagnostic sequence per source.
emptySupplementalDiagnosticGroupFragments ::
     [AcquiredSupplementalSource] -> [CanonicalFragment]
emptySupplementalDiagnosticGroupFragments =
  map (\source -> supplementalSourceFragment source [])

preparedAuthorityFragment ::
     PreparedAuthority authority profile document -> CanonicalFragment
preparedAuthorityFragment (PreparedAuthority contract profile model) =
  closedObjectFragment
    [ requiredMember
        "adapter"
        (adapterDescriptorFragment (adapterContractDescriptor contract))
    , requiredMember
        "notationRules"
        (arrayFragment
           (concatMap
              (notationRuleBindingFragments contract)
              (NonEmpty.toList allArchiMateNotationIssueKinds)))
    , requiredMember "profile" (profileDescriptorFragment profile)
    , requiredMember "model" (sourceIdentityFragment model)
    ]

notationRuleBindingFragments ::
     CompiledAdapterContract
  -> ArchiMateNotationIssueKind
  -> [CanonicalFragment]
notationRuleBindingFragments contract kind =
  case lookupArchiMateNotationRule kind contract of
    Nothing -> []
    Just rule ->
      [ closedObjectFragment
          [ requiredMember
              "evidenceKind"
              (textFragment
                 ("archimate-notation-" <> archiMateNotationIssueKindToken kind))
          , requiredMember
              "ruleId"
              (textFragment (adapterRuleIdText (adapterRuleId rule)))
          ]
      ]

profileDescriptorFragment :: ProfileDescriptor -> CanonicalFragment
profileDescriptorFragment =
  foldProfileDescriptor $ \identity token version notation adapterIds digest ->
    closedObjectFragment
      [ requiredMember "identity" (textFragment identity)
      , requiredMember "token" (textFragment token)
      , requiredMember "version" (textFragment version)
      , requiredMember "notation" (textFragment notation)
      , requiredMember
          "adapterIds"
          (arrayFragment (map textFragment adapterIds))
      , requiredMember "contractDigest" (textFragment digest)
      ]

preparedDiagnosticFragment ::
     PreparedDiagnostic authority profile document -> CanonicalFragment
preparedDiagnosticFragment diagnostic =
  foldPreparedDiagnostic
    notation
    activation
    rejection
    classification
    mapping
    invariant
    structure
    semantics
    diagnostic
  where
    wrapWithoutRule = wrapWithRule Nothing
    wrap evidenceKind evidence =
      wrapWithRule
        (Just (preparedDiagnosticRuleIdentity diagnostic))
        evidenceKind
        evidence
    wrapWithRule ruleIdentity evidenceKind evidence =
      closedObjectFragment
        ([ requiredMember
             "producer"
             (textFragment (preparedDiagnosticProducer diagnostic))
         , requiredMember
             "owner"
             (textFragment (preparedDiagnosticOwner diagnostic))
         , requiredMember
             "stage"
             (textFragment (preparedDiagnosticStage diagnostic))
         , requiredMember "evidenceKind" (textFragment evidenceKind)
         , requiredMember
             "severity"
             (textFragment
                (diagnosticSeverityText (preparedDiagnosticSeverity diagnostic)))
         , requiredMember
             "disposition"
             (textFragment
                (diagnosticDispositionText
                   (preparedDiagnosticDisposition diagnostic)))
         , requiredMember "evidence" evidence
         ]
           <> maybe
                []
                (\rule -> [requiredMember "ruleId" (textFragment rule)])
                ruleIdentity)
    notation evidence =
      foldAdapterNotationDiagnostic
        (\_ _ issue ->
           wrapWithoutRule
             ("archimate-notation-"
                <> archiMateNotationIssueKindToken
                     (archiMateNotationIssueKind issue))
             (evidenceFragment
                []
                [ fieldFragment
                    "subject"
                    [ draftLocationFragment
                        (archiMateNotationIssueSubject issue)
                    ]
                , fieldFragment
                    "observations"
                    (map
                       notationEvidenceFragment
                       (NonEmpty.toList (archiMateNotationIssueEvidence issue)))
                ]))
        evidence
    activation evidence =
      Closure.foldActivationProvenance
        (\_ _ branch _ owner trigger sourceRules ->
           wrap
             "activation-provenance"
             (evidenceFragment
                [ requiredMember
                    "branch"
                    (textFragment
                       (Closure.foldClosureBranch "graph" "qualification" branch))
                , requiredMember
                    "sourceRuleIds"
                    (arrayFragment (map textFragment sourceRules))
                ]
                [ fieldFragment "owner" [canonicalOccurrenceFragment owner]
                , fieldFragment "trigger" [canonicalOccurrenceFragment trigger]
                ]))
        evidence
    rejection evidence =
      Profile.foldProfileDiagnosticEvidence
        (\_ value ->
           let (kind, fields) = profileEvidenceFragment value
            in wrap kind (evidenceFragment [] fields))
        evidence
    classification evidence =
      Profile.foldProfileClassificationEvidence
        (\graph qualification _ occurrence ->
           wrap
             "classification-occurrence"
             (evidenceFragment
                [ requiredMember
                    "class"
                    (textFragment (classificationText graph qualification))
                , requiredMember "graphMembership" (booleanFragment graph)
                , requiredMember
                    "qualificationMembership"
                    (booleanFragment qualification)
                ]
                [ fieldFragment
                    "classifiedOccurrence"
                    [canonicalOccurrenceFragment occurrence]
                ]))
        evidence
    mapping evidence =
      Profile.foldProfileMappingProvenance
        (\_ occurrence mappingId ->
           wrap
             "carrier-occurrence"
             (mappingEvidence
                mappingId
                [fieldFragment "carrier" [coreIdentityFragment occurrence]]))
        (\_ occurrence mappingId source target ->
           wrap
             "relationship-occurrence"
             (mappingEvidence
                mappingId
                [ fieldFragment "relationship" [coreIdentityFragment occurrence]
                , fieldFragment "source" [coreIdentityFragment source]
                , fieldFragment "target" [coreIdentityFragment target]
                ]))
        (\_ occurrence mappingId ->
           wrap
             (profileEvidenceKindText
                (Profile.profileMappingEvidenceKind evidence))
             (mappingEvidence
                mappingId
                [ fieldFragment
                    "constructedOccurrence"
                    [coreIdentityFragment occurrence]
                ]))
        evidence
    invariant evidence =
      Profile.foldProfileInvariantEvidence
        (\_ value ->
           let (kind, fields) = profileEvidenceFragment value
            in wrap kind (evidenceFragment [] fields))
        evidence
    structure evidence =
      let (kind, fields) = structureEvidenceFragment evidence
       in wrap kind (evidenceFragment [] fields)
    semantics evidence =
      Semantics.foldSemanticDiagnosticEvidence
        (semanticDiagnosticEliminator wrap)
        evidence

classificationText :: Bool -> Bool -> Text
classificationText graph qualification =
  case (graph, qualification) of
    (True, True) -> "both"
    (True, False) -> "graph-only"
    (False, True) -> "qualification-only"
    (False, False) -> "neither"

mappingEvidence :: Text -> [CanonicalFragment] -> CanonicalFragment
mappingEvidence mappingId =
  evidenceFragment [requiredMember "mappingId" (textFragment mappingId)]

evidenceFragment ::
     [CanonicalMember] -> [CanonicalFragment] -> CanonicalFragment
evidenceFragment members fields =
  closedObjectFragment
    (members <> [requiredMember "fields" (arrayFragment fields)])

fieldFragment :: Text -> [CanonicalFragment] -> CanonicalFragment
fieldFragment role values =
  closedObjectFragment
    [ requiredMember "role" (textFragment role)
    , requiredMember "values" (arrayFragment values)
    ]

coreIdentityFragment :: OccurrenceIdentity -> CanonicalFragment
coreIdentityFragment = textFragment . occurrenceIdentityText

modelIdentityFragment :: ModelIdentity -> CanonicalFragment
modelIdentityFragment = textFragment . modelIdentityText

profileEvidenceKindText :: Profile.ProfileEvidenceKind -> Text
profileEvidenceKindText =
  Profile.foldProfileEvidenceKind
    "carrier-occurrence"
    "classification-occurrence"
    "metadata-owner-and-o2i-property-occurrences"
    "property-occurrence-evidence"
    "property-slot-evidence"
    "property-value-evidence"
    "proposal-carrier-occurrence"
    "proposal-reference-incidence"
    "relationship-occurrence"
    "reserved-property-occurrence"
    "structured-carrier-occurrence"
    "structured-incidence"

profileEvidenceFragment ::
     Profile.ProfileEvidence profile document kind
  -> (Text, [CanonicalFragment])
profileEvidenceFragment evidence =
  ( profileEvidenceKindText (Profile.profileEvidenceKind evidence)
  , Profile.foldProfileEvidence
      (\occurrence -> canonicalField "carrier" [occurrence])
      (\occurrence -> canonicalField "classifiedOccurrence" [occurrence])
      (\owner properties ->
         [ canonicalValues "owner" [owner]
         , canonicalValues "properties" properties
         ])
      (\property owner ->
         [ canonicalValues "property" [property]
         , canonicalValues "owner" [owner]
         ])
      (\owner key properties ->
         [ canonicalValues "owner" [owner]
         , fieldFragment "key" [textFragment key]
         , canonicalValues "properties" properties
         ])
      (\property owner scalars ->
         [ canonicalValues "property" [property]
         , canonicalValues "owner" [owner]
         , fieldFragment "scalars" (map draftScalarFragment scalars)
         ])
      (\occurrence -> canonicalField "proposal" [occurrence])
      (\occurrence proposal related ->
         [ canonicalValues "reference" [occurrence]
         , canonicalValues "proposal" [proposal]
         , canonicalValues "related" related
         ])
      (\occurrence -> canonicalField "relationship" [occurrence])
      (\property owner key ->
         [ canonicalValues "property" [property]
         , canonicalValues "owner" [owner]
         , fieldFragment "key" [textFragment key]
         ])
      (\occurrence -> canonicalField "carrier" [occurrence])
      (\occurrence related ->
         [ canonicalValues "incidence" [occurrence]
         , canonicalValues "related" related
         ])
      evidence)
  where
    canonicalField role values = [canonicalValues role values]
    canonicalValues role = fieldFragment role . map canonicalOccurrenceFragment

structureEvidenceFragment ::
     Structure.StructureEvidence scope -> (Text, [CanonicalFragment])
structureEvidenceFragment =
  Structure.foldStructureEvidence
    Structure.StructureDefectEliminator
      { Structure.eliminateQualifiedEndpointCatalogMembership =
          \value ->
            exact
              "qualified-endpoint-catalog-membership"
              [ ( "subject"
                , [Structure.qualifiedEndpointCatalogMembershipSubject value])
              ]
      , Structure.eliminateContextualizationSourceCategory =
          \value ->
            exact
              "contextualization-source-category"
              [ ( "segment"
                , [Structure.contextualizationSourceCategorySegment value])
              , ( "owner"
                , [Structure.contextualizationSourceCategoryOwner value])
              ]
      , Structure.eliminateContextualizationTargetCategory =
          \value ->
            exact
              "contextualization-target-category"
              [ ( "segment"
                , [Structure.contextualizationTargetCategorySegment value])
              , ( "member"
                , [Structure.contextualizationTargetCategoryMember value])
              ]
      , Structure.eliminateContextualizationTargetOwnerCardinality =
          \value ->
            exact
              "contextualization-target-owner-cardinality"
              [ ( "member"
                , [ Structure.contextualizationTargetOwnerCardinalityMember
                      value
                  ])
              , ( "owners"
                , Structure.foldStructureZeroOrMultipleOccurrences
                    []
                    (\first second remaining -> first : second : remaining)
                    (Structure.contextualizationTargetOwnerCardinalityOwners
                       value))
              ]
      , Structure.eliminateSemanticRelationCompatibility =
          \value ->
            exact
              "semantic-relation-compatibility"
              [ ( "relation"
                , [Structure.semanticRelationCompatibilityRelation value])
              , ( "source"
                , [Structure.semanticRelationCompatibilitySource value])
              , ( "target"
                , [Structure.semanticRelationCompatibilityTarget value])
              ]
      , Structure.eliminateStructuredPropositionIdentity =
          \value ->
            exact
              "structured-proposition-identity"
              [ ( "subject"
                , [Structure.structuredPropositionIdentitySubject value])
              , ( "occurrences"
                , Structure.structuredPropositionIdentityFirstOccurrence value
                    : Structure.structuredPropositionIdentitySecondOccurrence
                        value
                    : Structure.structuredPropositionIdentityRemainingOccurrences
                        value)
              ]
      , Structure.eliminateCollectiveParticipantType =
          \value ->
            exact
              "collective-participant-type"
              [ ("claim", [Structure.collectiveParticipantTypeClaim value])
              , ("segment", [Structure.collectiveParticipantTypeSegment value])
              , ( "endpoint"
                , [Structure.collectiveParticipantTypeEndpoint value])
              ]
      , Structure.eliminateCollectiveParticipantCardinality =
          \value ->
            exact
              "collective-participant-cardinality"
              [ ( "claim"
                , [Structure.collectiveParticipantCardinalityClaim value])
              , ( "endpoints"
                , maybe
                    []
                    (: [])
                    (Structure.collectiveParticipantCardinalitySoleEndpoint
                       value))
              ]
      , Structure.eliminateCollectiveParticipantUniqueness =
          \value ->
            exact
              "collective-participant-uniqueness"
              [ ( "claim"
                , [Structure.collectiveParticipantUniquenessClaim value])
              , ( "duplicateEndpoints"
                , NonEmpty.toList
                    (Structure.collectiveParticipantUniquenessDuplicateEndpoints
                       value))
              ]
      , Structure.eliminateCollectiveTargetType =
          \value ->
            exact
              "collective-target-type"
              [ ("claim", [Structure.collectiveTargetTypeClaim value])
              , ("segment", [Structure.collectiveTargetTypeSegment value])
              , ("endpoint", [Structure.collectiveTargetTypeEndpoint value])
              ]
      , Structure.eliminateCollectiveTargetCardinality =
          \value ->
            exact
              "collective-target-cardinality"
              [ ("claim", [Structure.collectiveTargetCardinalityClaim value])
              , ( "endpoints"
                , Structure.foldStructureZeroOrMultipleOccurrences
                    []
                    (\first second remaining -> first : second : remaining)
                    (Structure.collectiveTargetCardinalityEndpoints value))
              ]
      , Structure.eliminateCollectiveTargetDistinctness =
          \value ->
            exact
              "collective-target-distinctness"
              [ ("claim", [Structure.collectiveTargetDistinctnessClaim value])
              , ( "overlappingEndpoints"
                , NonEmpty.toList
                    (Structure.collectiveTargetDistinctnessOverlappingEndpoints
                       value))
              ]
      }
  where
    exact kind values =
      ( kind
      , [ fieldFragment role (map coreIdentityFragment occurrences)
        | (role, occurrences) <- values
        ])

semanticDiagnosticEliminator ::
     (Text -> CanonicalFragment -> CanonicalFragment)
  -> Semantics.SemanticDiagnosticEliminator CanonicalFragment
semanticDiagnosticEliminator wrap =
  Semantics.SemanticDiagnosticEliminator
    { Semantics.eliminateCollectiveAssertedCollectiveCoverage =
        \claim uncovered ->
          exact
            "FitClaimKey"
            [ model "claim" claim
            , occurrences "uncovered-target-member" (NonEmpty.toList uncovered)
            ]
    , Semantics.eliminateCollectiveAssertedCompleteness =
        \claim occurrence ->
          exact
            "FitClaimKey"
            [model "claim" claim, occurrences "claim" [occurrence]]
    , Semantics.eliminateCollectiveAssertedMacroSupport =
        \claim participant claimOccurrence participantOccurrence targetOccurrence ->
          exact
            "ParticipantClaimKey"
            [ model "claim" claim
            , model "participant" participant
            , occurrences "claim" [claimOccurrence]
            , occurrences "participant" [participantOccurrence]
            , occurrences "target" [targetOccurrence]
            ]
    , Semantics.eliminateCollectiveAssertedParticipantPrimitiveSupport =
        \claim participant claimOccurrence participantOccurrence targetOccurrence ->
          exact
            "ParticipantClaimKey"
            [ model "claim" claim
            , model "participant" participant
            , occurrences "claim" [claimOccurrence]
            , occurrences "participant" [participantOccurrence]
            , occurrences "target" [targetOccurrence]
            ]
    , Semantics.eliminateCollectiveFitPairwiseCoherence = fitClaim "claim"
    , Semantics.eliminateCollectiveFitParticipantBinding = fitClaim "claim"
    , Semantics.eliminateCollectiveFitParticipantCompatibility =
        fitClaim "claim"
    , Semantics.eliminateCollectiveFitTargetBinding = fitClaim "claim"
    , Semantics.eliminateCollectiveFitTargetGuidingPolicy = fitClaim "claim"
    , Semantics.eliminateCollectiveFitTargetTradeOffs = fitClaim "claim"
    , Semantics.eliminateContextualizationAssertedDependency =
        \dependent endpoint context dependentOccurrence endpointOccurrence contextOccurrence ->
          exact
            "AssertedDependencyKey"
            [ occurrences "dependent" [dependent]
            , occurrences "endpoint" [endpoint]
            , occurrences "context" [context]
            , occurrences "dependent" [dependentOccurrence]
            , occurrences "contextualized-endpoint" [endpointOccurrence]
            , occurrences "candidate-contextualization" [contextOccurrence]
            ]
    , Semantics.eliminateSituatedNeedDriverAnchoring =
        needMember "unanchored-driver"
    , Semantics.eliminateSituatedNeedDriverCardinality =
        \need ->
          exact "NeedKey" [model "need" need, occurrences "observed-driver" []]
    , Semantics.eliminateSituatedNeedObjectiveCardinality =
        \need ->
          exact
            "NeedKey"
            [model "need" need, occurrences "observed-objective" []]
    , Semantics.eliminateSituatedNeedObjectiveGrounding =
        needMember "ungrounded-objective"
    , Semantics.eliminateSituatedNeedSurfacingSituationAnchoring =
        needMember "unanchored-surfacing-situation"
    , Semantics.eliminateSituatedNeedSurfacingSituationCardinality =
        \need ->
          exact
            "NeedKey"
            [model "need" need, occurrences "observed-surfacing-situation" []]
    , Semantics.eliminateStrategyFormulationActionContributions =
        strategyMember "uncontributing-action"
    , Semantics.eliminateStrategyFormulationActions =
        \strategy values ->
          exact
            "StrategyKey"
            [ model "strategy" strategy
            , occurrences "listed-action" (NonEmpty.toList values)
            ]
    , Semantics.eliminateStrategyFormulationDiagnosis =
        strategyMany "owned-diagnosis"
    , Semantics.eliminateStrategyFormulationDiagnosisGrounding =
        \strategy diagnosis intent ->
          exact
            "StrategyKey"
            [ model "strategy" strategy
            , occurrences "diagnosis" [diagnosis]
            , occurrences "intent" [intent]
            ]
    , Semantics.eliminateStrategyFormulationGuidingPolicy =
        strategyMany "owned-guiding-policy"
    , Semantics.eliminateStrategyFormulationGuidingPolicyActions =
        \strategy member policy action ->
          exact
            "StrategyMemberKey"
            [ model "strategy" strategy
            , model "member" member
            , occurrences "guiding-policy" [policy]
            , occurrences "action" [action]
            ]
    , Semantics.eliminateStrategyFormulationIntent = strategyMany "owned-intent"
    , Semantics.eliminateStrategyFormulationKeyResultSubstantiation =
        \strategy member keyResult intent ->
          exact
            "StrategyMemberKey"
            [ model "strategy" strategy
            , model "member" member
            , occurrences "key-result" [keyResult]
            , occurrences "intent" [intent]
            ]
    , Semantics.eliminateStrategyFormulationKeyResults =
        \strategy values ->
          exact
            "StrategyKey"
            [ model "strategy" strategy
            , occurrences "listed-key-result" (NonEmpty.toList values)
            ]
    , Semantics.eliminateStrategyFormulationVisionOrientation =
        \strategy ->
          exact
            "StrategyKey"
            [ model "strategy" strategy
            , occurrences "observed-vision-orientation" []
            ]
    }
  where
    exact kind fields = wrap kind (evidenceFragment [] fields)
    model role identity = fieldFragment role [modelIdentityFragment identity]
    occurrences role identities =
      fieldFragment role (map coreIdentityFragment identities)
    fitClaim role claim occurrence =
      exact "FitClaimKey" [model "claim" claim, occurrences role [occurrence]]
    needMember role need member occurrence =
      exact
        "NeedMemberKey"
        [ model "need" need
        , model "member" member
        , occurrences role [occurrence]
        ]
    strategyMember role strategy member occurrence =
      exact
        "StrategyMemberKey"
        [ model "strategy" strategy
        , model "member" member
        , occurrences role [occurrence]
        ]
    strategyMany role strategy values =
      exact "StrategyKey" [model "strategy" strategy, occurrences role values]

supplementalGroupMember ::
     SupplementalDiagnosticGroup authority profile document -> CanonicalMember
supplementalGroupMember group =
  case group of
    SupplementalDiagnosticGroup source evidence ->
      let identity =
            foldAcquiredSupplementalSource acquiredSourceIdentity source
       in requiredMember
            (Text.pack
               (show (sourceOrdinalValue (sourceIdentityOrdinal identity))))
            (supplementalSourceFragment
               source
               (map bindingDiagnosticFragment evidence))

supplementalGroupFragment ::
     SupplementalDiagnosticGroup authority profile document -> CanonicalFragment
supplementalGroupFragment group =
  case group of
    SupplementalDiagnosticGroup source evidence ->
      supplementalSourceFragment source (map bindingDiagnosticFragment evidence)

supplementalSourceFragment ::
     AcquiredSupplementalSource -> [CanonicalFragment] -> CanonicalFragment
supplementalSourceFragment source diagnostics =
  let identity = foldAcquiredSupplementalSource acquiredSourceIdentity source
   in closedObjectFragment
        [ requiredMember
            "reference"
            (textFragment
               (sourceReferenceText (sourceIdentityReference identity)))
        , requiredMember
            "sha256"
            (textFragment (sourceSha256Text (sourceIdentitySha256 identity)))
        , requiredMember "diagnostics" (arrayFragment diagnostics)
        ]

bindingDiagnosticFragment ::
     SupplementalOwnerBindingEvidence scope inputs -> CanonicalFragment
bindingDiagnosticFragment (SupplementalOwnerBindingEvidence evidence) =
  Binding.foldSupplementalBindingDiagnosticEvidence
    (const
       (identityFinding
          Binding.supplementalIdentityUnknownInstancePointer
          Binding.supplementalIdentityUnknownModelIdentity))
    (const
       (identityFinding
          Binding.supplementalIdentityAmbiguousInstancePointer
          Binding.supplementalIdentityAmbiguousModelIdentity))
    (const
       (identityFinding
          Binding.supplementalIdentityWrongTypeInstancePointer
          Binding.supplementalIdentityWrongTypeModelIdentity))
    (const
       (identityFinding
          Binding.supplementalIdentityOutOfViewInstancePointer
          Binding.supplementalIdentityOutOfViewModelIdentity))
    evidence
  where
    identityFinding pointer project value =
      closedObjectFragment
        [ requiredMember "producer" (textFragment "supplemental-binding")
        , requiredMember "owner" (textFragment "core")
        , requiredMember "stage" (textFragment "capability-input")
        , requiredMember
            "ruleId"
            (textFragment
               (coreRuleIdText
                  (Binding.supplementalBindingDiagnosticEvidenceRule evidence)))
        , requiredMember
            "evidenceKind"
            (textFragment "supplemental-identity-site")
        , requiredMember "severity" (textFragment "error")
        , requiredMember
            "disposition"
            (textFragment (diagnosticDispositionText processFailure))
        , requiredMember
            "evidence"
            (evidenceFragment
               []
               [ fieldFragment "instancePointer" [textFragment (pointer value)]
               , fieldFragment
                   "identity"
                   [modelIdentityFragment (project value)]
               ])
        ]

notationEvidenceFragment :: ArchiMateNotationEvidence -> CanonicalFragment
notationEvidenceFragment =
  foldArchiMateNotationEvidence
    (\location ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "occurrence")
         , requiredMember "location" (draftLocationFragment location)
         ])
    (\location valueKind value ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "value")
         , requiredMember "location" (draftLocationFragment location)
         , requiredMember "valueKind" (draftValueKindFragment valueKind)
         , requiredMember "value" (textFragment value)
         ])
    (\location value targets ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "reference")
         , requiredMember "location" (draftLocationFragment location)
         , requiredMember "value" (textFragment value)
         , requiredMember
             "targets"
             (arrayFragment (map draftLocationFragment targets))
         ])

viewDescriptorFragment :: CanonicalView document -> CanonicalFragment
viewDescriptorFragment descriptor =
  closedObjectFragment
    [ requiredMember
        "occurrence"
        (canonicalOccurrenceFragment (canonicalViewOccurrence descriptor))
    , requiredMember
        "identity"
        (identityOutcomeFragment (canonicalViewIdentity descriptor))
    , requiredMember
        "nameFields"
        (arrayFragment
           (fmap canonicalFieldFragment (canonicalViewNameFields descriptor)))
    , requiredMember
        "location"
        (draftLocationFragment (canonicalViewLocation descriptor))
    ]

adapterRuleFragment :: AdapterRule -> CanonicalFragment
adapterRuleFragment rule =
  closedObjectFragment
    [ requiredMember
        "id"
        (textFragment (adapterRuleIdText (adapterRuleId rule)))
    , requiredMember
        "stage"
        (textFragment (adapterRuleStageText (adapterRuleStage rule)))
    , requiredMember "expectation" (textFragment (adapterRuleExpectation rule))
    , requiredMember "meaning" (textFragment (adapterRuleMeaning rule))
    , requiredMember "action" (textFragment (adapterRuleAction rule))
    ]

adapterOccurrenceFragment :: AdapterOccurrence -> CanonicalFragment
adapterOccurrenceFragment =
  foldAdapterOccurrence nullFragment nativeLocationFragment

nativeLocationFragment :: NativeLocation -> CanonicalFragment
nativeLocationFragment =
  foldNativeLocation
    (\offset ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "byte-offset")
         , requiredMember "offset" (naturalFragment offset)
         ])
    (\line column ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "line-column")
         , requiredMember "line" (naturalFragment line)
         , requiredMember "column" (naturalFragment column)
         ])
    (\steps ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "path")
         , requiredMember
             "steps"
             (arrayFragment (fmap textFragment (NonEmpty.toList steps)))
         ])

sourceFailureFragment :: Text -> Text -> IOException -> CanonicalFragment
sourceFailureFragment kind reference exception =
  closedObjectFragment
    [ requiredMember "sourceKind" (textFragment kind)
    , requiredMember "sourceReference" (textFragment reference)
    , requiredMember
        "message"
        (textFragment (Text.pack (displayException exception)))
    ]

sourceRoleText :: SourceRole -> Text
sourceRoleText role =
  case role of
    ModelRole -> "model"
    SupplementalRole -> "supplemental"
    ReadinessRole -> "readiness"
    AssessmentRole -> "assessment"

canonicalOccurrenceFragment :: CanonicalOccurrence -> CanonicalFragment
canonicalOccurrenceFragment occurrence =
  closedObjectFragment
    [ requiredMember
        "kind"
        (textFragment
           (foldCanonicalOccurrenceKind
              "record"
              "property"
              "reference"
              (canonicalOccurrenceKind occurrence)))
    , requiredMember
        "ordinal"
        (naturalFragment (canonicalOccurrenceOrdinal occurrence))
    ]

identityOutcomeFragment :: IdentityOutcome -> CanonicalFragment
identityOutcomeFragment =
  foldIdentityOutcome
    (closedObjectFragment [requiredMember "kind" (textFragment "missing")])
    (\scalars ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "multiple")
         , requiredMember
             "values"
             (arrayFragment (fmap draftScalarFragment scalars))
         ])
    (\scalar reason ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "invalid")
         , requiredMember "value" (draftScalarFragment scalar)
         , requiredMember "reason" (identityInvalidReasonFragment reason)
         ])
    (\scalar identifier ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "resolved")
         , requiredMember "value" (draftScalarFragment scalar)
         , requiredMember
             "identity"
             (textFragment (modelIdentityText identifier))
         ])

identityInvalidReasonFragment :: IdentityInvalidReason -> CanonicalFragment
identityInvalidReasonFragment =
  foldIdentityInvalidReason
    (\kind ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "non-text")
         , requiredMember "observedKind" (draftValueKindFragment kind)
         ])
    (closedObjectFragment [requiredMember "kind" (textFragment "empty")])
    (closedObjectFragment [requiredMember "kind" (textFragment "u0000")])
    (closedObjectFragment [requiredMember "kind" (textFragment "surrogate")])

canonicalFieldFragment :: CanonicalField -> CanonicalFragment
canonicalFieldFragment field =
  closedObjectFragment
    [ requiredMember "kind" (draftFieldValueFragment (canonicalFieldKind field))
    , requiredMember
        "values"
        (arrayFragment (fmap draftScalarFragment (canonicalFieldScalars field)))
    , requiredMember
        "location"
        (draftLocationFragment (canonicalFieldLocation field))
    ]

draftFieldValueFragment :: DraftFieldValue -> CanonicalFragment
draftFieldValueFragment =
  textFragment
    . foldDraftFieldValue
        "type"
        "name"
        "documentation"
        "directed"
        "influence-strength"

draftScalarFragment :: DraftScalar -> CanonicalFragment
draftScalarFragment scalar =
  closedObjectFragment
    [ requiredMember
        "value"
        (foldDraftScalarValue
           (scalarValue "text" . textFragment)
           (scalarValue "boolean" . booleanFragment)
           (scalarValue "number" . textFragment)
           (scalarValue "native-name" . draftNativeNameFragment)
           (\kind value ->
              closedObjectFragment
                [ requiredMember "kind" (textFragment "other")
                , requiredMember "nativeKind" (textFragment kind)
                , requiredMember "value" (textFragment value)
                ])
           scalar)
    , requiredMember
        "location"
        (draftLocationFragment (draftScalarLocation scalar))
    ]
  where
    scalarValue kind value =
      closedObjectFragment
        [ requiredMember "kind" (textFragment kind)
        , requiredMember "value" value
        ]

draftValueKindFragment :: DraftValueKind -> CanonicalFragment
draftValueKindFragment =
  textFragment . foldDraftValueKind "text" "boolean" "number" "native-name" id

draftNativeNameFragment :: DraftNativeName -> CanonicalFragment
draftNativeNameFragment name =
  closedObjectFragment
    [ requiredMember
        "namespace"
        (maybe nullFragment textFragment (draftNativeNamespace name))
    , requiredMember "localName" (textFragment (draftNativeLocalName name))
    ]

draftLocationFragment :: DraftLocation -> CanonicalFragment
draftLocationFragment location =
  closedObjectFragment
    [ requiredMember
        "path"
        (foldDraftSourcePath
           (\first rest ->
              arrayFragment (fmap draftPathStepFragment (first : rest)))
           (draftLocationPath location))
    , requiredMember
        "span"
        (maybe nullFragment draftSourceSpanFragment (draftLocationSpan location))
    ]

draftPathStepFragment :: DraftPathStep -> CanonicalFragment
draftPathStepFragment step =
  closedObjectFragment
    [ requiredMember "name" (draftNativeNameFragment (draftPathStepName step))
    , requiredMember "ordinal" (naturalFragment (draftPathStepOrdinal step))
    ]

draftSourceSpanFragment :: DraftSourceSpan -> CanonicalFragment
draftSourceSpanFragment sourceSpan =
  closedObjectFragment
    [ requiredMember
        "start"
        (draftSourcePositionFragment (draftSpanStart sourceSpan))
    , requiredMember
        "end"
        (draftSourcePositionFragment (draftSpanEnd sourceSpan))
    ]

draftSourcePositionFragment :: DraftSourcePosition -> CanonicalFragment
draftSourcePositionFragment position =
  closedObjectFragment
    [ requiredMember "line" (naturalFragment (draftSourceLine position))
    , requiredMember "column" (naturalFragment (draftSourceColumn position))
    , requiredMember
        "offset"
        (maybe nullFragment naturalFragment (draftSourceOffset position))
    ]
