-- | Family validation for structured O2I propositions.
module O2I.Structure.Proposition
  ( assessStructuredPropositions
  ) where

import Data.List (sort, sortOn)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import O2I.Core.Contract
  ( CoreQualifiedEndpointId
  , CoreStructuredPropositionRoleId
  )
import O2I.Core.Contract.Internal
  ( CoreStructuredPropositionFamilyKind(..)
  , coreStructuredFamilyParticipantEndpoint
  , coreStructuredFamilyParticipantRole
  , coreStructuredFamilyTargetEndpoint
  , coreStructuredFamilyTargetRole
  , coreStructuredPropositionFamilyKind
  )
import O2I.Core.Graph.Observation
  ( CarrierObservation
  , carrierOccurrenceIdentity
  , carrierQualifiedEndpoint
  )
import O2I.Core.Identity (OccurrenceIdentity, SelectedViewScope)
import O2I.Core.Identity.Internal
  ( ScopedOccurrence
  , modelIdentityOccurrenceIdentities
  , scopedOccurrenceModelIdentity
  )
import O2I.Structure.Internal

-- | Validate every structured proposition independently and canonically.
assessStructuredPropositions ::
     SelectedViewScope scope
  -> Map OccurrenceIdentity (CarrierObservation scope)
  -> Map
       OccurrenceIdentity
       (StructuredPropositionProjection, ScopedOccurrence scope)
  -> [StructuredIncidenceProjection]
  -> ([StructureDefect], [StructuredPropositionObservation scope])
assessStructuredPropositions scope carriers propositions incidences =
  (sort (identityDefects ++ familyDefects), observations)
  where
    groupedIncidences =
      Map.fromListWith
        (++)
        [ (claim, [incidence])
        | incidence@(StructuredIncidenceProjection _ claim _ _) <- incidences
        ]
    assessed =
      [ assessOne
        carriers
        propositionWithScope
        (sortOn
           incidenceOccurrence
           (Map.findWithDefault [] occurrence groupedIncidences))
      | propositionWithScope@(StructuredPropositionProjection occurrence _ _ _, _) <-
          Map.elems propositions
      ]
    identityDefects =
      [ StructureDefect StructuredPropositionIdentityRule subject occurrences
      | (identifier, subject) <- Map.toAscList propositionSubjects
      , let occurrences = modelIdentityOccurrenceIdentities scope identifier
      , length occurrences /= 1
      ]
    propositionSubjects =
      Map.fromListWith
        min
        [ (scopedOccurrenceModelIdentity scoped, occurrence)
        | (StructuredPropositionProjection occurrence _ _ _, scoped) <-
            Map.elems propositions
        ]
    familyDefects = concatMap fst assessed
    observations = concatMap snd assessed

assessOne ::
     Map OccurrenceIdentity (CarrierObservation scope)
  -> (StructuredPropositionProjection, ScopedOccurrence scope)
  -> [StructuredIncidenceProjection]
  -> ([StructureDefect], [StructuredPropositionObservation scope])
assessOne carriers (proposition, scoped) incidences =
  (familyDefects, [observation])
  where
    StructuredPropositionProjection occurrence family completeness commitment =
      proposition
    modelIdentifier = scopedOccurrenceModelIdentity scoped
    participantRole = coreStructuredFamilyParticipantRole family
    targetRole = coreStructuredFamilyTargetRole family
    participantEndpoint = coreStructuredFamilyParticipantEndpoint family
    targetEndpoint = coreStructuredFamilyTargetEndpoint family
    participantIncidences = incidencesForRole participantRole incidences
    targetIncidences = incidencesForRole targetRole incidences
    participantOccurrences = incidenceEndpoints participantIncidences
    targetOccurrences = incidenceEndpoints targetIncidences
    familyDefects =
      case coreStructuredPropositionFamilyKind family of
        CollectiveStrategyRealizationFamily ->
          endpointTypeDefects
            CollectiveParticipantTypeRule
            occurrence
            participantEndpoint
            carriers
            participantIncidences
            ++ cardinalityDefect
                 CollectiveParticipantCardinalityRule
                 occurrence
                 ((>= 2) (length participantOccurrences))
                 participantOccurrences
            ++ uniquenessDefect occurrence participantOccurrences
            ++ endpointTypeDefects
                 CollectiveTargetTypeRule
                 occurrence
                 targetEndpoint
                 carriers
                 targetIncidences
            ++ cardinalityDefect
                 CollectiveTargetCardinalityRule
                 occurrence
                 (length targetOccurrences == 1)
                 targetOccurrences
            ++ distinctnessDefect
                 occurrence
                 participantOccurrences
                 targetOccurrences
    observation =
      StructuredPropositionObservation
        occurrence
        modelIdentifier
        family
        completeness
        commitment
        (map incidenceObservation incidences)

incidenceOccurrence :: StructuredIncidenceProjection -> OccurrenceIdentity
incidenceOccurrence (StructuredIncidenceProjection occurrence _ _ _) =
  occurrence

incidencesForRole ::
     CoreStructuredPropositionRoleId
  -> [StructuredIncidenceProjection]
  -> [StructuredIncidenceProjection]
incidencesForRole expected =
  filter (\(StructuredIncidenceProjection _ _ role _) -> role == expected)

incidenceEndpoints :: [StructuredIncidenceProjection] -> [OccurrenceIdentity]
incidenceEndpoints =
  map (\(StructuredIncidenceProjection _ _ _ endpoint) -> endpoint)

incidenceObservation ::
     StructuredIncidenceProjection -> StructuredIncidenceObservation scope
incidenceObservation (StructuredIncidenceProjection occurrence _ role endpoint) =
  StructuredIncidenceObservation occurrence role endpoint

endpointTypeDefects ::
     StructureRule
  -> OccurrenceIdentity
  -> CoreQualifiedEndpointId
  -> Map OccurrenceIdentity (CarrierObservation scope)
  -> [StructuredIncidenceProjection]
  -> [StructureDefect]
endpointTypeDefects rule proposition expected carriers = foldr collect []
  where
    collect (StructuredIncidenceProjection segment _ _ endpoint) defects =
      case Map.lookup endpoint carriers of
        Just carrier
          | carrierQualifiedEndpoint carrier /= expected ->
            StructureDefect
              rule
              proposition
              [segment, carrierOccurrenceIdentity carrier]
              : defects
        _ -> defects

cardinalityDefect ::
     StructureRule
  -> OccurrenceIdentity
  -> Bool
  -> [OccurrenceIdentity]
  -> [StructureDefect]
cardinalityDefect rule proposition satisfied related =
  [StructureDefect rule proposition (sort related) | not satisfied]

uniquenessDefect ::
     OccurrenceIdentity -> [OccurrenceIdentity] -> [StructureDefect]
uniquenessDefect proposition participants =
  [ StructureDefect CollectiveParticipantUniquenessRule proposition duplicates
  | not (null duplicates)
  ]
  where
    duplicates =
      Map.keys
        (Map.filter
           (> (1 :: Int))
           (Map.fromListWith
              (+)
              [(participant, 1 :: Int) | participant <- participants]))

distinctnessDefect ::
     OccurrenceIdentity
  -> [OccurrenceIdentity]
  -> [OccurrenceIdentity]
  -> [StructureDefect]
distinctnessDefect proposition participants targets =
  [ StructureDefect CollectiveTargetDistinctnessRule proposition overlaps
  | not (null overlaps)
  ]
  where
    overlaps =
      Set.toAscList
        (Set.fromList participants `Set.intersection` Set.fromList targets)
