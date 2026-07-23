{-# LANGUAGE OverloadedStrings #-}

-- | Native collective Strategy-realization projection and View closure.
module O2I.Adapter.AMX.Internal.Profile.Collective
  ( collectiveFacts
  , collectiveDefects
  , collectiveRawClaims
  , isCollectiveClaimCandidate
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Set as Set
import O2I
import O2I.Adapter.AMX.Internal.Defect
import O2I.Adapter.AMX.Internal.Profile.Collective.Index
import O2I.Adapter.AMX.Internal.Profile.Collective.Syntax
import O2I.Adapter.AMX.Internal.Profile.Model
import O2I.Adapter.AMX.Internal.Types
import O2I.Inspection.Profile
import O2I.Inspection.Provenance

-- | Project complete collective claims and every closure dependency without
-- manufacturing binary semantic edges.
collectiveFacts :: CollectiveIndex -> [IndexedProfileFact SourcePosition]
collectiveFacts index = concatMap facts (collectiveObservations index)
  where
    facts observation =
      claimOccurrenceFact
        : segmentOccurrenceFacts
        ++ segmentDependencies
        ++ claimFact
      where
        junction = observedJunction observation
        claimOccurrence = nodeOccurrence junction
        segments = observedSegments observation
        claimOccurrenceFact =
          indexOccurrence claimOccurrence (amxElementLocation junction)
        segmentOccurrenceFacts =
          [ indexOccurrence
            (relationshipOccurrence segment)
            (amxElementLocation segment)
          | segment <- segments
          ]
        segmentDependencies =
          concat
            [ [ indexDependency
                  segmentOccurrence
                  claimOccurrence
                  PersistedCollectiveRealizationSegment
              , indexDependency
                  claimOccurrence
                  segmentOccurrence
                  PersistedCollectiveRealizationSegment
              ]
            | segment <- segments
            , let segmentOccurrence = relationshipOccurrence segment
            ]
        claimFact =
          case (observedRawClaim observation, observedTargets observation) of
            (Just claim, [target]) ->
              [ indexCollectiveStrategyRealization
                  claimOccurrence
                  claim
                  (map nodeOccurrence (observedContributors observation))
                  (nodeOccurrence target)
                  (amxElementLocation junction)
              ]
            _ -> []

-- | Enumerate globally well-formed native collective claims with commitment.
collectiveRawClaims ::
     CollectiveIndex -> [Claim RawCollectiveStrategyRealization]
collectiveRawClaims =
  foldr
    (\observation rest ->
       case observedRawClaim observation of
         Nothing -> rest
         Just claim -> claim : rest)
    []
    . collectiveObservations

-- | Retain complete-model syntax findings until the selected View reaches any
-- Junction or segment occurrence of the claim.
collectiveDefects ::
     Environment
  -> CollectiveIndex
  -> [DeferredProfileDefect SourcePosition AMXProfileDefect]
collectiveDefects environment index =
  concatMap deferred (collectiveObservations index)
  where
    deferred observation =
      map (defer observation) (observedDefects observation)
        ++ partialViewFinding environment observation
    defer observation defect =
      DeferredProfileDefect
        { defectApplicability =
            ReachedProfileDefect (observationOccurrences observation)
        , deferredDefect = defect
        }

partialViewFinding ::
     Environment
  -> CollectiveObservation
  -> [DeferredProfileDefect SourcePosition AMXProfileDefect]
partialViewFinding environment observation =
  case (observedRawClaim observation, shown < total) of
    (Just claim, True) ->
      [ DeferredProfileDefect
          { defectApplicability =
              ReachedProfileDefect (observationOccurrences observation)
          , deferredDefect =
              Located
                (amxElementLocation
                   (selectedViewElement (environmentSelectedView environment)))
                (PartialCollectiveView
                   (claimIdText (rawRealizationId (claimedProposition claim)))
                   shown
                   total)
          }
      ]
    _ -> []
  where
    incomingOccurrences =
      Set.fromList (map relationshipOccurrence (observedIncoming observation))
    shown =
      Set.size
        (Set.intersection
           incomingOccurrences
           (environmentPresentedRelations environment))
    total = length (observedContributors observation)

observationOccurrences :: CollectiveObservation -> NonEmpty OccurrenceId
observationOccurrences observation =
  nodeOccurrence (observedJunction observation)
    :| map relationshipOccurrence (observedSegments observation)
