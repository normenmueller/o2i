{-# LANGUAGE OverloadedStrings #-}

-- | Addressed structural assessment for one selected O2I View.
--
-- Construction indexes every projection and reference once. Validation then
-- uses only addressed maps and sets; it never builds a Cartesian product or a
-- general graph-query structure.
module O2I.Structure.Index
  ( assessStructure
  ) where

import Data.List (sort, sortOn)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import O2I.Core.Contract (CoreCarrierCategory, CoreO2IType)
import O2I.Core.Contract.Internal
  ( CoreCarrierCategoryKind(..)
  , coreCarrierCategoryKind
  , coreSemanticRelationIsCompatible
  , lookupCoreQualifiedEndpointFor
  )
import O2I.Core.Graph.Observation.Internal
  ( CarrierObservation(..)
  , ContextualizationObservation(..)
  , RelationObservation(..)
  , ScopedGraphOccurrence(..)
  , carrierQualifiedEndpoint
  )
import O2I.Core.Identity (OccurrenceIdentity, SelectedViewScope)
import O2I.Core.Identity.Internal
  ( ScopedOccurrence
  , lookupScopedOccurrence
  , scopedOccurrenceModelIdentity
  )
import O2I.Structure.Internal
import O2I.Structure.Proposition (assessStructuredPropositions)

-- | Assess one complete selected-View projection.
--
-- Projection-boundary failures are distinguished from model Structure rule
-- failures. Both collections are complete and canonically ordered.
assessStructure ::
     SelectedViewScope scope
  -> StructureProjection
  -> Either (NonEmpty StructureInputDefect) (StructureAssessment scope)
assessStructure scope projection =
  case scopeStructureProjection scope projection of
    Left defects -> Left defects
    Right scoped -> Right (assessValidProjection scope scoped)

scopeStructureProjection ::
     SelectedViewScope scope
  -> StructureProjection
  -> Either (NonEmpty StructureInputDefect) (ScopedStructureProjection scope)
scopeStructureProjection scope projection =
  case structureInputDefects scope projection of
    defect:defects -> Left (defect :| defects)
    [] ->
      ScopedStructureProjection
        <$> traverse scopeCarrier carriers
        <*> pure contextualizations
        <*> pure relations
        <*> traverse scopeProposition propositions
        <*> pure incidences
  where
    StructureProjection carriers contextualizations relations propositions incidences =
      projection
    scopeCarrier carrier@(CarrierProjection occurrence _ _ _) =
      case lookupScopedOccurrence scope occurrence of
        Just scoped -> Right (carrier, scoped)
        Nothing -> Left (ProjectionOutsideSelectedView occurrence :| [])
    scopeProposition proposition@(StructuredPropositionProjection occurrence _ _ _) =
      case lookupScopedOccurrence scope occurrence of
        Just scoped -> Right (proposition, scoped)
        Nothing -> Left (ProjectionOutsideSelectedView occurrence :| [])

assessValidProjection ::
     SelectedViewScope scope
  -> ScopedStructureProjection scope
  -> StructureAssessment scope
assessValidProjection scope projection =
  case sort defects of
    defect:remaining -> StructureRejected (defect :| remaining)
    [] -> StructureAccepted graph
  where
    ScopedStructureProjection carrierProjections contextualizationProjections relationProjections propositionProjections incidenceProjections =
      projection
    carrierSeeds =
      Map.fromList
        [ (occurrence, carrier)
        | (carrier@(CarrierProjection occurrence _ _ _), _) <-
            carrierProjections
        ]
    contextualizationSeeds =
      Map.fromList
        [ (occurrence, contextualization)
        | contextualization@(ContextualizationProjection occurrence _ _ _) <-
            contextualizationProjections
        ]
    relationSeeds =
      Map.fromList
        [ (occurrence, relation)
        | relation@(RelationProjection occurrence _ _ _ _) <-
            relationProjections
        ]
    propositionSeeds =
      Map.fromList
        [ (occurrence, (proposition, scoped))
        | (proposition@(StructuredPropositionProjection occurrence _ _ _), scoped) <-
            propositionProjections
        ]
    validContextualizations =
      filter
        (contextualizationCategoriesAreValid carrierSeeds)
        (Map.elems contextualizationSeeds)
    ownersByMember =
      Map.fromListWith
        (++)
        [ (member, [owner])
        | ContextualizationProjection _ owner member _ <-
            validContextualizations
        ]
    contextualizationDefects =
      concatMap
        (contextualizationCategoryDefects carrierSeeds)
        (Map.elems contextualizationSeeds)
        ++ ownerCardinalityDefects carrierSeeds ownersByMember
    carrierAssessment =
      Map.fromList
        [ ( occurrence
          , qualifyCarrier scoped carrierSeeds ownersByMember carrier)
        | (carrier@(CarrierProjection occurrence _ _ _), scoped) <-
            carrierProjections
        ]
    carrierDefects = concatMap fst (Map.elems carrierAssessment)
    carriers = Map.mapMaybe singletonObservation carrierAssessment
    relationAssessment = map (assessRelation carriers) (Map.elems relationSeeds)
    relationDefects = concatMap fst relationAssessment
    relations = concatMap snd relationAssessment
    contextualizations =
      map contextualizationObservation (Map.elems contextualizationSeeds)
    (propositionDefects, propositions) =
      assessStructuredPropositions
        scope
        carriers
        propositionSeeds
        incidenceProjections
    defects =
      contextualizationDefects
        ++ carrierDefects
        ++ relationDefects
        ++ propositionDefects
    graph =
      WellFormedGraph
        { wellFormedSelectedViewScope = scope
        , storedWellFormedCarriers = Map.elems carriers
        , storedWellFormedContextualizations = contextualizations
        , storedWellFormedRelations = relations
        , storedWellFormedStructuredPropositions = propositions
        }

singletonObservation :: ([StructureDefect], Maybe value) -> Maybe value
singletonObservation (_, value) = value

structureInputDefects ::
     SelectedViewScope scope -> StructureProjection -> [StructureInputDefect]
structureInputDefects scope projection =
  sortOn inputDefectKey (outsideDefects ++ duplicateDefects ++ missingDefects)
  where
    StructureProjection carriers contextualizations relations propositions incidences =
      projection
    ownOccurrences =
      [ (occurrence, CarrierProjectionKind)
      | CarrierProjection occurrence _ _ _ <- carriers
      ]
        ++ [ (occurrence, ContextualizationProjectionKind)
           | ContextualizationProjection occurrence _ _ _ <- contextualizations
           ]
        ++ [ (occurrence, RelationProjectionKind)
           | RelationProjection occurrence _ _ _ _ <- relations
           ]
        ++ [ (occurrence, StructuredPropositionProjectionKind)
           | StructuredPropositionProjection occurrence _ _ _ <- propositions
           ]
        ++ [ (occurrence, StructuredIncidenceProjectionKind)
           | StructuredIncidenceProjection occurrence _ _ _ <- incidences
           ]
    references =
      map fst ownOccurrences
        ++ [ owner
           | ContextualizationProjection _ owner _ _ <- contextualizations
           ]
        ++ [ member
           | ContextualizationProjection _ _ member _ <- contextualizations
           ]
        ++ [source | RelationProjection _ source _ _ _ <- relations]
        ++ [target | RelationProjection _ _ _ target _ <- relations]
        ++ [claim | StructuredIncidenceProjection _ claim _ _ <- incidences]
        ++ [ endpoint
           | StructuredIncidenceProjection _ _ _ endpoint <- incidences
           ]
    outsideDefects =
      [ ProjectionOutsideSelectedView occurrence
      | occurrence <- Set.toAscList (Set.fromList references)
      , lookupScopedOccurrence scope occurrence == Nothing
      ]
    kindsByOccurrence =
      Map.fromListWith
        (++)
        [(occurrence, [kind]) | (occurrence, kind) <- ownOccurrences]
    duplicateDefects =
      [ DuplicateStructureProjection occurrence (first :| rest)
      | (occurrence, kinds) <- Map.toAscList kindsByOccurrence
      , let orderedKinds = sort kinds
      , first:rest <- [orderedKinds]
      , not (null rest)
      ]
    carrierOccurrences =
      Set.fromList [occurrence | CarrierProjection occurrence _ _ _ <- carriers]
    propositionOccurrences =
      Set.fromList
        [ occurrence
        | StructuredPropositionProjection occurrence _ _ _ <- propositions
        ]
    missingDefects =
      [ MissingCarrierProjection occurrence ContextualizationOwnerRole owner
      | ContextualizationProjection occurrence owner _ _ <- contextualizations
      , Set.notMember owner carrierOccurrences
      ]
        ++ [ MissingCarrierProjection
             occurrence
             ContextualizationMemberRole
             member
           | ContextualizationProjection occurrence _ member _ <-
               contextualizations
           , Set.notMember member carrierOccurrences
           ]
        ++ [ MissingCarrierProjection occurrence RelationSourceRole source
           | RelationProjection occurrence source _ _ _ <- relations
           , Set.notMember source carrierOccurrences
           ]
        ++ [ MissingCarrierProjection occurrence RelationTargetRole target
           | RelationProjection occurrence _ _ target _ <- relations
           , Set.notMember target carrierOccurrences
           ]
        ++ [ MissingCarrierProjection
             occurrence
             StructuredIncidenceEndpointRole
             endpoint
           | StructuredIncidenceProjection occurrence _ _ endpoint <- incidences
           , Set.notMember endpoint carrierOccurrences
           ]
        ++ [ MissingStructuredPropositionProjection occurrence claim
           | StructuredIncidenceProjection occurrence claim _ _ <- incidences
           , Set.notMember claim propositionOccurrences
           ]

inputDefectKey ::
     StructureInputDefect -> (OccurrenceIdentity, Int, OccurrenceIdentity, Int)
inputDefectKey defect =
  case defect of
    ProjectionOutsideSelectedView occurrence -> (occurrence, 0, occurrence, 0)
    DuplicateStructureProjection occurrence _ -> (occurrence, 1, occurrence, 0)
    MissingCarrierProjection occurrence role endpoint ->
      (occurrence, 2, endpoint, fromEnum role)
    MissingStructuredPropositionProjection occurrence claim ->
      (occurrence, 3, claim, 0)

contextualizationCategoriesAreValid ::
     Map OccurrenceIdentity CarrierProjection
  -> ContextualizationProjection
  -> Bool
contextualizationCategoriesAreValid carriers contextualization =
  null (contextualizationCategoryDefects carriers contextualization)

contextualizationCategoryDefects ::
     Map OccurrenceIdentity CarrierProjection
  -> ContextualizationProjection
  -> [StructureDefect]
contextualizationCategoryDefects carriers projection =
  sourceDefect ++ targetDefect
  where
    ContextualizationProjection occurrence owner member _ = projection
    sourceDefect =
      [ StructureDefect ContextualizationSourceCategoryRule occurrence [owner]
      | Just (CarrierProjection _ category _ _) <- [Map.lookup owner carriers]
      , coreCarrierCategoryKind category /= ContextCarrierCategory
      ]
    targetDefect =
      [ StructureDefect ContextualizationTargetCategoryRule occurrence [member]
      | Just (CarrierProjection _ category _ _) <- [Map.lookup member carriers]
      , not (isOwnedCarrierCategory category)
      ]

ownerCardinalityDefects ::
     Map OccurrenceIdentity CarrierProjection
  -> Map OccurrenceIdentity [OccurrenceIdentity]
  -> [StructureDefect]
ownerCardinalityDefects carriers ownersByMember =
  [ StructureDefect
    ContextualizationTargetOwnerCardinalityRule
    member
    (sort owners)
  | (member, CarrierProjection _ category _ _) <- Map.toAscList carriers
  , isOwnedCarrierCategory category
  , let owners = Map.findWithDefault [] member ownersByMember
  , length owners /= 1
  ]

qualifyCarrier ::
     ScopedOccurrence scope
  -> Map OccurrenceIdentity CarrierProjection
  -> Map OccurrenceIdentity [OccurrenceIdentity]
  -> CarrierProjection
  -> ([StructureDefect], Maybe (CarrierObservation scope))
qualifyCarrier scoped carriers ownersByMember projection =
  case derivedEndpoint of
    Nothing -> (membershipDefect, Nothing)
    Just endpoint ->
      ( []
      , Just
          (CarrierObservation
             (ScopedGraphOccurrence occurrence)
             (scopedOccurrenceModelIdentity scoped)
             endpoint
             commitment))
  where
    CarrierProjection occurrence category o2iType commitment = projection
    contextType =
      case Map.findWithDefault [] occurrence ownersByMember of
        [owner] -> carrierType <$> Map.lookup owner carriers
        _ -> Nothing
    requiredContext
      | isOwnedCarrierCategory category = contextType
      | otherwise = Nothing
    canQualify
      | isOwnedCarrierCategory category =
        case contextType of
          Just _ -> True
          Nothing -> False
      | otherwise = True
    derivedEndpoint
      | canQualify =
        lookupCoreQualifiedEndpointFor category requiredContext o2iType
      | otherwise = Nothing
    membershipDefect =
      [ StructureDefect QualifiedEndpointCatalogMembershipRule occurrence []
      | canQualify
      ]

carrierType :: CarrierProjection -> CoreO2IType
carrierType (CarrierProjection _ _ o2iType _) = o2iType

assessRelation ::
     Map OccurrenceIdentity (CarrierObservation scope)
  -> RelationProjection
  -> ([StructureDefect], [RelationObservation scope])
assessRelation carriers projection =
  case (Map.lookup source carriers, Map.lookup target carriers) of
    (Just sourceCarrier, Just targetCarrier)
      | coreSemanticRelationIsCompatible
          token
          (carrierQualifiedEndpoint sourceCarrier)
          (carrierQualifiedEndpoint targetCarrier) ->
        ( []
        , [ RelationObservation
              (ScopedGraphOccurrence occurrence)
              (ScopedGraphOccurrence source)
              token
              (ScopedGraphOccurrence target)
              commitment
          ])
      | otherwise ->
        ( [ StructureDefect
              SemanticRelationCompatibilityRule
              occurrence
              [source, target]
          ]
        , [])
    _ -> ([], [])
  where
    RelationProjection occurrence source token target commitment = projection

contextualizationObservation ::
     ContextualizationProjection -> ContextualizationObservation scope
contextualizationObservation (ContextualizationProjection occurrence owner member commitment) =
  ContextualizationObservation
    (ScopedGraphOccurrence occurrence)
    (ScopedGraphOccurrence owner)
    (ScopedGraphOccurrence member)
    commitment

isOwnedCarrierCategory :: CoreCarrierCategory -> Bool
isOwnedCarrierCategory category =
  case coreCarrierCategoryKind category of
    PrimitiveCarrierCategory -> True
    StructuringCarrierCategory -> True
    ContextCarrierCategory -> False
    SituationAnchorCarrierCategory -> False
