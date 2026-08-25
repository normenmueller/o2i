{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}

-- | Private canonical indexing of selected-View graph observations.
--
-- Construction performs one pass over the observations after building
-- addressed sets and maps. For @V@ selected memberships and @N@ retained
-- occurrence references, work is @O((V + N) log (1 + V + N))@ and additional
-- retention is @O(V + N)@. Each input observation is accumulated exactly
-- once. Validation then traverses only the addressed collections and retained
-- endpoint requirements; it never rescans the observation input.
module O2I.Core.Graph.Observation.Index
  ( GraphObservationInput(..)
  , GraphObservationKind(..)
  , GraphEndpointRole(..)
  , GraphObservationIndex
  , GraphObservationIndexDefect(..)
  , GraphObservationBuildWork
  , graphBuildSelectedMemberships
  , graphBuildObservationVisits
  , graphBuildReferenceVisits
  , graphBuildIndexEntries
  , withGraphObservationIndex
  , selectedViewScopeForGraph
  , graphCarrierObservations
  , graphRelationObservations
  , graphContextualizationObservations
  , graphObservationBuildWork
  ) where

import Data.List (sort, sortOn)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Set (Set)
import O2I.Core.Contract (CoreQualifiedEndpointId, CoreRelationToken)
import O2I.Core.Graph.Commitment (Commitment)
import O2I.Core.Graph.Observation.Internal
import O2I.Core.Identity
  ( ModelIdentityIndex
  , ModelOccurrence
  , OccurrenceIdentity
  , SelectedViewScope
  , SelectedViewScopeDefect
  , selectedViewScopeDefectOccurrence
  , withSelectedViewScope
  )
import O2I.Core.Identity.Internal
  ( lookupScopedOccurrence
  , scopedOccurrenceModelIdentity
  )

-- | Structure-owned input for one canonical observation.
--
-- Constructors remain package-private. They contain only closed Core
-- vocabulary and canonical occurrence identities, never notation values.
data GraphObservationInput
  = CarrierObservationInput
      !OccurrenceIdentity
      !CoreQualifiedEndpointId
      !Commitment
  | RelationObservationInput
      !OccurrenceIdentity
      !OccurrenceIdentity
      !CoreRelationToken
      !OccurrenceIdentity
      !Commitment
  | ContextualizationObservationInput
      !OccurrenceIdentity
      !OccurrenceIdentity
      !OccurrenceIdentity
      !Commitment
  deriving (Eq, Ord, Show)

-- | Closed observation kind used only in construction-defect evidence.
data GraphObservationKind
  = CarrierObservationKind
  | RelationObservationKind
  | ContextualizationObservationKind
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Closed endpoint role used only in construction-defect evidence.
data GraphEndpointRole
  = RelationSourceRole
  | RelationTargetRole
  | ContextualizationOwnerRole
  | ContextualizationMemberRole
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Private canonical observation index for one nominal selected View.
type role GraphObservationIndex nominal

data GraphObservationIndex scope =
  GraphObservationIndex
    !(SelectedViewScope scope)
    !(Map OccurrenceIdentity (CarrierObservation scope))
    !(Map OccurrenceIdentity (RelationObservation scope))
    !(Map OccurrenceIdentity (ContextualizationObservation scope))
    !GraphObservationBuildWork

-- | Closed construction failure. These values report a violated Core
-- boundary, not a model-semantic diagnostic and therefore carry no rule ID.
data GraphObservationIndexDefect
  = SelectedViewScopeRejected !SelectedViewScopeDefect
  | ObservationOutsideSelectedView !OccurrenceIdentity
  | DuplicateGraphObservation
      !OccurrenceIdentity
      !(NonEmpty GraphObservationKind)
  | MissingCarrierEndpoint
      !OccurrenceIdentity
      !GraphEndpointRole
      !OccurrenceIdentity
  deriving (Eq, Show)

-- | Private exact work evidence for focused asymptotic regression tests.
data GraphObservationBuildWork =
  GraphObservationBuildWork !Int !Int !Int !Int
  deriving (Eq, Show)

data GraphObservationBuild = GraphObservationBuild
  { observedKinds :: !(Map OccurrenceIdentity [GraphObservationKind])
  , observedReferences :: !(Set OccurrenceIdentity)
  , carrierSeeds :: !(Map OccurrenceIdentity CarrierObservationSeed)
  , relationSeeds :: !(Map OccurrenceIdentity RelationObservationSeed)
  , contextualizationSeeds :: !(Map
                                  OccurrenceIdentity
                                  ContextualizationObservationSeed)
  , requiredEndpoints :: ![( OccurrenceIdentity
                           , GraphEndpointRole
                           , OccurrenceIdentity)]
  , observedInputs :: !Int
  , observedReferenceCount :: !Int
  }

data CarrierObservationSeed =
  CarrierObservationSeed !CoreQualifiedEndpointId !Commitment

data RelationObservationSeed =
  RelationObservationSeed
    !OccurrenceIdentity
    !CoreRelationToken
    !OccurrenceIdentity
    !Commitment

data ContextualizationObservationSeed =
  ContextualizationObservationSeed
    !OccurrenceIdentity
    !OccurrenceIdentity
    !Commitment

-- | Number of selected-membership occurrences supplied to construction.
graphBuildSelectedMemberships :: GraphObservationBuildWork -> Int
graphBuildSelectedMemberships (GraphObservationBuildWork memberships _ _ _) =
  memberships

-- | Number of observation inputs visited during construction.
graphBuildObservationVisits :: GraphObservationBuildWork -> Int
graphBuildObservationVisits (GraphObservationBuildWork _ visits _ _) = visits

-- | Number of own and endpoint references visited while accumulating.
graphBuildReferenceVisits :: GraphObservationBuildWork -> Int
graphBuildReferenceVisits (GraphObservationBuildWork _ _ visits _) = visits

-- | Number of canonical entries retained across all observation maps.
graphBuildIndexEntries :: GraphObservationBuildWork -> Int
graphBuildIndexEntries (GraphObservationBuildWork _ _ _ entries) = entries

-- | Validate one selected-View boundary and build its canonical observations.
--
-- The rank-2 continuation prevents the nominal View scope and every value tied
-- to it from escaping. Scope defects precede graph-boundary defects because no
-- scoped observation can exist until selected membership is valid.
withGraphObservationIndex ::
     ModelIdentityIndex
  -> ModelOccurrence
  -> [OccurrenceIdentity]
  -> [GraphObservationInput]
  -> (forall scope. SelectedViewScope scope -> GraphObservationIndex scope -> result)
  -> Either (NonEmpty GraphObservationIndexDefect) result
withGraphObservationIndex modelIndex selectedView selected inputs action =
  case withSelectedViewScope modelIndex selectedView selected buildWithinScope of
    Left defects -> Left (SelectedViewScopeRejected <$> defects)
    Right result -> result
  where
    buildWithinScope scope =
      case graphBuildDefects selected build of
        defect:defects -> Left (defect :| defects)
        [] ->
          case finishIndex scope selected build of
            Left defect -> Left (defect :| [])
            Right index -> Right (action scope index)
      where
        build = foldl' accumulateObservation emptyGraphObservationBuild inputs

-- | Recover the exact selected-View witness retained by the private index.
selectedViewScopeForGraph ::
     GraphObservationIndex scope -> SelectedViewScope scope
selectedViewScopeForGraph (GraphObservationIndex scope _ _ _ _) = scope

-- | Canonically enumerate carriers for Core-internal stage consumption.
graphCarrierObservations ::
     GraphObservationIndex scope -> [CarrierObservation scope]
graphCarrierObservations (GraphObservationIndex _ carriers _ _ _) =
  Map.elems carriers

-- | Canonically enumerate relations for Core-internal stage consumption.
graphRelationObservations ::
     GraphObservationIndex scope -> [RelationObservation scope]
graphRelationObservations (GraphObservationIndex _ _ relations _ _) =
  Map.elems relations

-- | Canonically enumerate contextualizations for internal stage consumption.
graphContextualizationObservations ::
     GraphObservationIndex scope -> [ContextualizationObservation scope]
graphContextualizationObservations (GraphObservationIndex _ _ _ contextualizations _) =
  Map.elems contextualizations

-- | Read private exact work evidence.
graphObservationBuildWork ::
     GraphObservationIndex scope -> GraphObservationBuildWork
graphObservationBuildWork (GraphObservationIndex _ _ _ _ work) = work

emptyGraphObservationBuild :: GraphObservationBuild
emptyGraphObservationBuild =
  GraphObservationBuild
    { observedKinds = Map.empty
    , observedReferences = Set.empty
    , carrierSeeds = Map.empty
    , relationSeeds = Map.empty
    , contextualizationSeeds = Map.empty
    , requiredEndpoints = []
    , observedInputs = 0
    , observedReferenceCount = 0
    }

accumulateObservation ::
     GraphObservationBuild -> GraphObservationInput -> GraphObservationBuild
accumulateObservation build input =
  build
    { observedKinds =
        Map.insertWith
          (++)
          identifier
          [observationKind input]
          (observedKinds build)
    , observedReferences =
        foldl' (flip Set.insert) (observedReferences build) inputReferences
    , carrierSeeds = updatedCarriers
    , relationSeeds = updatedRelations
    , contextualizationSeeds = updatedContextualizations
    , requiredEndpoints = inputEndpointRequirements ++ requiredEndpoints build
    , observedInputs = observedInputs build + 1
    , observedReferenceCount =
        observedReferenceCount build + length inputReferences
    }
  where
    identifier = observationIdentity input
    inputReferences = observationReferences input
    inputEndpointRequirements = endpointRequirementsFor input
    updatedCarriers =
      case input of
        CarrierObservationInput _ endpoint commitment ->
          Map.insert
            identifier
            (CarrierObservationSeed endpoint commitment)
            (carrierSeeds build)
        _ -> carrierSeeds build
    updatedRelations =
      case input of
        RelationObservationInput _ source token target commitment ->
          Map.insert
            identifier
            (RelationObservationSeed source token target commitment)
            (relationSeeds build)
        _ -> relationSeeds build
    updatedContextualizations =
      case input of
        ContextualizationObservationInput _ owner member commitment ->
          Map.insert
            identifier
            (ContextualizationObservationSeed owner member commitment)
            (contextualizationSeeds build)
        _ -> contextualizationSeeds build

graphBuildDefects ::
     [OccurrenceIdentity]
  -> GraphObservationBuild
  -> [GraphObservationIndexDefect]
graphBuildDefects selected build =
  sortOn graphDefectKey (outsideDefects ++ duplicateDefects ++ endpointDefects)
  where
    selectedSet = Set.fromList selected
    outsideDefects =
      map
        ObservationOutsideSelectedView
        (Set.toAscList (observedReferences build `Set.difference` selectedSet))
    duplicateDefects =
      [ DuplicateGraphObservation identifier (first :| rest)
      | (identifier, kinds) <- Map.toAscList (observedKinds build)
      , let sortedKinds = sort kinds
      , first:rest <- [sortedKinds]
      , not (null rest)
      ]
    endpointDefects =
      [ MissingCarrierEndpoint observation role endpoint
      | (observation, role, endpoint) <- requiredEndpoints build
      , Map.notMember endpoint (carrierSeeds build)
      ]

graphDefectKey ::
     GraphObservationIndexDefect
  -> (OccurrenceIdentity, Int, OccurrenceIdentity, Int)
graphDefectKey defect =
  case defect of
    SelectedViewScopeRejected selectedDefect ->
      let identifier = selectedViewScopeDefectOccurrence selectedDefect
       in (identifier, 0, identifier, 0)
    ObservationOutsideSelectedView identifier -> (identifier, 1, identifier, 0)
    DuplicateGraphObservation identifier _ -> (identifier, 2, identifier, 0)
    MissingCarrierEndpoint observation role endpoint ->
      (observation, 3, endpoint, fromEnum role)

endpointRequirementsFor ::
     GraphObservationInput
  -> [(OccurrenceIdentity, GraphEndpointRole, OccurrenceIdentity)]
endpointRequirementsFor input =
  case input of
    CarrierObservationInput _ _ _ -> []
    RelationObservationInput occurrence source _ target _ ->
      [ (occurrence, RelationSourceRole, source)
      , (occurrence, RelationTargetRole, target)
      ]
    ContextualizationObservationInput occurrence owner member _ ->
      [ (occurrence, ContextualizationOwnerRole, owner)
      , (occurrence, ContextualizationMemberRole, member)
      ]

observationIdentity :: GraphObservationInput -> OccurrenceIdentity
observationIdentity input =
  case input of
    CarrierObservationInput occurrence _ _ -> occurrence
    RelationObservationInput occurrence _ _ _ _ -> occurrence
    ContextualizationObservationInput occurrence _ _ _ -> occurrence

observationKind :: GraphObservationInput -> GraphObservationKind
observationKind input =
  case input of
    CarrierObservationInput _ _ _ -> CarrierObservationKind
    RelationObservationInput _ _ _ _ _ -> RelationObservationKind
    ContextualizationObservationInput _ _ _ _ ->
      ContextualizationObservationKind

observationReferences :: GraphObservationInput -> [OccurrenceIdentity]
observationReferences input =
  case input of
    CarrierObservationInput occurrence _ _ -> [occurrence]
    RelationObservationInput occurrence source _ target _ ->
      [occurrence, source, target]
    ContextualizationObservationInput occurrence owner member _ ->
      [occurrence, owner, member]

finishIndex ::
     SelectedViewScope scope
  -> [OccurrenceIdentity]
  -> GraphObservationBuild
  -> Either GraphObservationIndexDefect (GraphObservationIndex scope)
finishIndex scope selected build =
  case traverseCarrierSeeds of
    Left defect -> Left defect
    Right carriers ->
      Right
        (GraphObservationIndex scope carriers relations contextualizations work)
  where
    scoped = ScopedGraphOccurrence
    traverseCarrierSeeds =
      Map.traverseWithKey canonicalCarrier (carrierSeeds build)
    canonicalCarrier occurrence (CarrierObservationSeed endpoint commitment) =
      case lookupScopedOccurrence scope occurrence of
        Nothing -> Left (ObservationOutsideSelectedView occurrence)
        Just canonicalOccurrence ->
          Right
            (CarrierObservation
               (scoped occurrence)
               (scopedOccurrenceModelIdentity canonicalOccurrence)
               endpoint
               commitment)
    relations =
      Map.mapWithKey
        (\occurrence (RelationObservationSeed source token target commitment) ->
           RelationObservation
             (scoped occurrence)
             (scoped source)
             token
             (scoped target)
             commitment)
        (relationSeeds build)
    contextualizations =
      Map.mapWithKey
        (\occurrence (ContextualizationObservationSeed owner member commitment) ->
           ContextualizationObservation
             (scoped occurrence)
             (scoped owner)
             (scoped member)
             commitment)
        (contextualizationSeeds build)
    work =
      GraphObservationBuildWork
        (length selected)
        (observedInputs build)
        (observedReferenceCount build)
        (Map.size (carrierSeeds build)
           + Map.size relations
           + Map.size contextualizations)
