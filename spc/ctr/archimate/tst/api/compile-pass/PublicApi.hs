{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module PublicApi where

import Data.List.NonEmpty (NonEmpty)
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

canonicalDocument :: Notation.CanonicalDocument
canonicalDocument = Notation.buildCanonicalDocument draftExample

notationAssessment :: Notation.NotationAssessment
notationAssessment = Notation.assessNotation canonicalDocument

markerAssessment :: Notation.MarkerEvidenceAssessment
markerAssessment = Notation.assessMarkerEvidence canonicalDocument

markerEvidenceCounts :: Notation.MarkerEvidenceAssessment -> (Int, Int)
markerEvidenceCounts =
  Notation.foldMarkerEvidenceAssessment
    (\candidates -> (length candidates, 0))
    (\candidates properties -> (length candidates, length properties))

closedViews :: [Closure.ClosedView]
closedViews =
  map Closure.closeSelectedView (Notation.viewInventory canonicalDocument)

projectClosedView ::
     Closure.ClosedView -> Projection.ProfileProjectionAssessment
projectClosedView = Projection.projectProfile

defectEvidenceOccurrences ::
     Projection.ProfileDefect -> (Text, [Notation.CanonicalOccurrence])
defectEvidenceOccurrences =
  Projection.foldProfileDefect
    (\rule evidence -> (rule, evidenceOccurrences evidence))
  where
    evidenceOccurrences ::
         Projection.ProfileEvidence kind -> [Notation.CanonicalOccurrence]
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
     Projection.ProfileContractFailure -> ContractFailureSummary
contractFailureSummary =
  Projection.foldProfileContractFailure
    UnknownRule
    EvidenceMismatch
    MissingCoreBinding
    InvalidOccurrenceIdentity

data ProjectionOutcome
  = ContractFailures !(NonEmpty Projection.ProfileContractFailure)
  | ModelDefects !(NonEmpty Projection.ProfileDefect)
  | ExactProjection !Projection.ProfileProjection

projectionOutcome :: Projection.ProfileProjectionAssessment -> ProjectionOutcome
projectionOutcome =
  Projection.foldProfileProjectionAssessment
    ContractFailures
    ModelDefects
    ExactProjection

projectionParts ::
     Projection.ProfileProjection -> [Projection.QualificationProposal]
projectionParts projection =
  Projection.profileStructureProjection projection
    `seq` Projection.profileQualificationProposals projection

qualificationProposalObservation ::
     Projection.QualificationProposal
  -> (Maybe Text, [Text], [Projection.QualificationReference])
qualificationProposalObservation proposal =
  Projection.qualificationProposalOccurrence proposal
    `seq` Projection.qualificationProposalIdentity proposal
    `seq` ( Projection.qualificationProposalRationale proposal
          , Projection.qualificationProposalSources proposal
          , Projection.qualificationProposalReferences proposal)

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
