{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module PublicApi where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified O2I.ArchiMate.Profile as Profile
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Mapping as Mapping
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Projection
import qualified O2I.ArchiMate.Profile.Resolution as Resolution
import qualified O2I.ArchiMate.Profile.Rule.Catalog as RuleCatalog
import qualified O2I.ArchiMate.Profile.Rule.Explanation as RuleExplanation

profileDescriptorObservations ::
     Profile.ProfileDescriptor -> (Text, Text, Text, Text, Text, [Text], Text)
profileDescriptorObservations descriptor =
  ( Profile.profileDescriptorIdentity descriptor
  , Profile.profileDescriptorToken descriptor
  , Profile.profileDescriptorReference descriptor
  , Profile.profileDescriptorVersion descriptor
  , Profile.profileDescriptorNotation descriptor
  , Profile.profileDescriptorAdapterIds descriptor
  , Profile.profileDescriptorContractDigest descriptor)

foldedDescriptorObservations ::
     Resolution.ProfileDescriptor -> (Text, Text, Text, Text, [Text], Text)
foldedDescriptorObservations =
  Resolution.foldProfileDescriptor
    (\profileIdentity token version notation adapters digest ->
       (profileIdentity, token, version, notation, adapters, digest))

sourceLocation :: Draft.DraftLocation
sourceLocation =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing "model") 0)
       [])
    Nothing

textScalar :: Text -> Draft.DraftScalar
textScalar value = Draft.draftTextScalar value sourceLocation

identity :: Text -> Draft.DraftIdentity recordRole
identity value = Draft.draftIdentity [textScalar value]

rootMarker :: Draft.DraftProperty Draft.ModelRootRole
rootMarker =
  Draft.draftProperty
    (Draft.directPropertyKey [textScalar "o2i.profile"])
    [ textScalar
        (Resolution.profileDescriptorIdentity
           Resolution.compiledProfileDescriptor)
    ]
    sourceLocation
    []

elementProperty :: Draft.DraftProperty Draft.ElementRole
elementProperty =
  Draft.draftProperty
    (Draft.directPropertyKey [textScalar "o2i.kind"])
    [textScalar "Context"]
    sourceLocation
    []

elementExample :: Draft.ElementDraft
elementExample =
  Draft.elementDraft
    (identity "element")
    sourceLocation
    [ Draft.typeFieldMember [textScalar "Grouping"] sourceLocation
    , Draft.nameFieldMember [textScalar "Strategy"] sourceLocation
    , Draft.propertyMember elementProperty
    ]

relationshipExample :: Draft.RelationshipDraft
relationshipExample =
  Draft.relationshipDraft
    (identity "relationship")
    sourceLocation
    [ Draft.typeFieldMember
        [textScalar "AssociationRelationship"]
        sourceLocation
    , Draft.nameFieldMember [textScalar "qualifies"] sourceLocation
    , Draft.directedFieldMember
        [Draft.draftBooleanScalar True sourceLocation]
        sourceLocation
    , Draft.referenceMember
        (Draft.relationshipSourceReference (identity "element") sourceLocation)
    , Draft.referenceMember
        (Draft.relationshipTargetReference (identity "element") sourceLocation)
    ]

viewNodeExample :: Draft.ViewNodeDraft
viewNodeExample =
  Draft.viewNodeDraft
    (identity "view-node")
    sourceLocation
    [ Draft.referenceMember
        (Draft.viewNodeElementReference (identity "element") sourceLocation)
    ]

viewConnectionExample :: Draft.ViewConnectionDraft
viewConnectionExample =
  Draft.viewConnectionDraft
    (identity "view-connection")
    sourceLocation
    [ Draft.referenceMember
        (Draft.viewConnectionRelationshipReference
           (identity "relationship")
           sourceLocation)
    , Draft.referenceMember
        (Draft.viewConnectionSourceReference
           (identity "view-node")
           sourceLocation)
    , Draft.referenceMember
        (Draft.viewConnectionTargetReference
           (identity "view-node")
           sourceLocation)
    ]

viewExample :: Draft.ViewDraft
viewExample =
  Draft.viewDraft
    (identity "view")
    sourceLocation
    [ Draft.nameFieldMember [textScalar "Main"] sourceLocation
    , Draft.childRecordMember viewNodeExample
    , Draft.childRecordMember viewConnectionExample
    ]

draftExample :: Draft.ProfileDraft
draftExample =
  Draft.profileDraft
    (Draft.modelRootDraft
       (identity "model")
       sourceLocation
       [ Draft.propertyMember rootMarker
       , Draft.childRecordMember elementExample
       , Draft.childRecordMember relationshipExample
       , Draft.childRecordMember viewExample
       ])

withCanonicalExample ::
     (forall document. Notation.CanonicalDocument document -> result) -> result
withCanonicalExample = Notation.withCanonicalDocument draftExample

markerEvidenceCounts :: Notation.MarkerEvidenceAssessment -> (Int, Int)
markerEvidenceCounts =
  Notation.foldMarkerEvidenceAssessment
    (\candidates -> (length candidates, 0))
    (\candidates properties -> (length candidates, length properties))

withAssessmentExample ::
     (forall profile document. Closure.ProfileAssessmentUniverse
                                 profile
                                 document -> result)
  -> result
withAssessmentExample consume =
  Resolution.withSelectedArchiMateProfile Resolution.compiledProfileDescriptor $ \profile ->
    withCanonicalExample $ \document ->
      case Notation.canonicalViews document of
        [] -> error "public API compile fixture has no View"
        view:_ ->
          consume
            (Closure.deriveProfileAssessmentUniverse profile document view)

projectionOutcomeExample :: Int
projectionOutcomeExample =
  withAssessmentExample $ \universe ->
    Notation.foldStageResult
      (const (error "public API compile fixture notation rejected"))
      (summarizeProjection . Projection.assessSelectedView)
      (Notation.notationConformance (Notation.assessArchiMateNotation universe))

defectEvidenceOccurrences ::
     Projection.ProfileDiagnosticEvidence profile document
  -> (Text, [Notation.CanonicalOccurrence])
defectEvidenceOccurrences =
  Projection.foldProfileDiagnosticEvidence
    (\rule evidence -> (rule, evidenceOccurrences evidence))
  where
    evidenceOccurrences ::
         Projection.ProfileEvidence profile document kind
      -> [Notation.CanonicalOccurrence]
    evidenceOccurrences =
      Projection.foldProfileEvidence
        pure
        pure
        (:)
        (\property owner -> [property, owner])
        (\owner _ properties -> owner : properties)
        (\property owner _ -> [property, owner])
        pure
        (\reference proposal related -> reference : proposal : related)
        pure
        (\property owner _ -> [property, owner])
        pure
        (:)

data ContractFailureSummary
  = UnknownRule !Text !Projection.ProfileEvidenceKind
  | EvidenceMismatch !Text !Projection.ProfileEvidenceKind
  | MissingCoreBinding !Text !Notation.CanonicalOccurrence
  | InvalidOccurrenceIdentity !Notation.CanonicalOccurrence !Text

contractFailureSummary ::
     Projection.ProfileContractEvidence profile document
  -> ContractFailureSummary
contractFailureSummary =
  Projection.foldProfileContractEvidence
    UnknownRule
    EvidenceMismatch
    MissingCoreBinding
    InvalidOccurrenceIdentity

data ProjectionOutcome profile document
  = ContractFailures
      !(NonEmpty (Projection.ProfileContractEvidence profile document))
  | ModelDefects
      !(NonEmpty (Projection.ProfileDiagnosticEvidence profile document))
  | ExactProjection !(Projection.ProfileProjection profile document)

projectionOutcome ::
     Projection.ProfileProjectionAssessment profile document
  -> ProjectionOutcome profile document
projectionOutcome =
  Projection.foldProfileProjectionAssessment
    ContractFailures
    ModelDefects
    ExactProjection

summarizeProjection ::
     Projection.ProfileProjectionAssessment profile document -> Int
summarizeProjection =
  Projection.foldProfileProjectionAssessment
    NonEmpty.length
    NonEmpty.length
    (length . Projection.profileMappingProvenance)

projectionParts ::
     Projection.ProfileProjection profile document
  -> [Projection.QualificationProposal]
projectionParts projection =
  Projection.withProfileStructureAssessment
    projection
    (const [])
    (const [])
    (const [])
    (const (Projection.profileQualificationProposals projection))

classificationEvidenceObservation ::
     Projection.ProfileProjection profile document -> [(Text, ())]
classificationEvidenceObservation =
  map
    (Projection.foldProfileClassificationEvidence
       (\graph qualification rule occurrence ->
          graph `seq` qualification `seq` (rule, occurrence `seq` ())))
    . Projection.profileClassificationEvidence

mappingProvenanceObservation ::
     Projection.ProfileMappingProvenance profile document -> ()
mappingProvenanceObservation provenance =
  Projection.profileMappingEvidenceKind provenance
    `seq` Projection.foldProfileMappingProvenance
            (\rule occurrence mappingId ->
               rule `seq` occurrence `seq` mappingId `seq` ())
            (\rule occurrence mappingId source target ->
               rule
                 `seq` occurrence
                 `seq` mappingId
                 `seq` source
                 `seq` target
                 `seq` ())
            (\rule occurrence mappingId ->
               rule `seq` occurrence `seq` mappingId `seq` ())
            provenance

invariantEvidenceObservation ::
     Projection.ProfileProjection profile document
  -> [(Text, Projection.ProfileEvidenceKind)]
invariantEvidenceObservation =
  map
    (Projection.foldProfileInvariantEvidence
       (\rule evidence -> (rule, Projection.profileEvidenceKind evidence)))
    . Projection.profileQualificationInvariantEvidence

qualificationProposalObservation ::
     Projection.QualificationProposal
  -> ( Maybe (Draft.DraftLocation, Text)
     , [Text]
     , [Projection.QualificationReference])
qualificationProposalObservation proposal =
  Projection.qualificationProposalOccurrence proposal
    `seq` Projection.qualificationProposalIdentity proposal
    `seq` ( fmap
              qualificationRationaleObservation
              (Projection.qualificationProposalRationale proposal)
          , map
              qualificationSourceObservation
              (Projection.qualificationProposalSources proposal)
          , Projection.qualificationProposalReferences proposal)

qualificationRationaleObservation ::
     Projection.QualificationRationale -> (Draft.DraftLocation, Text)
qualificationRationaleObservation rationale =
  ( Projection.qualificationRationaleLocation rationale
  , Projection.qualificationRationaleValue rationale)

qualificationSourceObservation :: Projection.QualificationSource -> Text
qualificationSourceObservation source =
  Projection.qualificationSourceOccurrence source
    `seq` Projection.qualificationSourceValue source

qualificationReferenceObservation :: Projection.QualificationReference -> ()
qualificationReferenceObservation reference =
  Projection.qualificationReferenceOccurrence reference
    `seq` Projection.qualificationReferenceRole reference
    `seq` Projection.qualificationReferenceTarget reference
    `seq` ()

mappingInventory :: ([Mapping.CarrierMapping], [Mapping.RelationMapping])
mappingInventory = (Mapping.carrierMappings, Mapping.relationMappings)

ruleCatalogEntries :: NonEmpty RuleExplanation.ProfileRuleExplanation
ruleCatalogEntries =
  RuleCatalog.selectedProfileRuleCatalogEntries
    RuleCatalog.selectedProfileRuleCatalog

lookupRule :: Text -> Maybe RuleExplanation.ProfileRuleExplanation
lookupRule =
  RuleCatalog.lookupSelectedProfileRule RuleCatalog.selectedProfileRuleCatalog

ruleObservation ::
     RuleExplanation.ProfileRuleExplanation
  -> ( RuleExplanation.ProfileRuleId
     , RuleExplanation.ProfileRuleAuthority
     , Text
     , Text
     , RuleExplanation.ProfileRuleStage
     , Text
     , Text
     , Text)
ruleObservation = RuleExplanation.foldProfileRuleExplanation (,,,,,,,)

catalogObservation ::
     (Text, Text, NonEmpty RuleExplanation.ProfileRuleExplanation)
catalogObservation =
  RuleCatalog.foldSelectedProfileRuleCatalog
    (,,)
    RuleCatalog.selectedProfileRuleCatalog
