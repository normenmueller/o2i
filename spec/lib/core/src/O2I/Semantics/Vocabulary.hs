-- | Compile-time-selected vocabulary used by fixed Core semantic rules.
--
-- Exhaustive generated constructors keep semantic behavior coupled to the
-- compiled companion without partial text lookups.
module O2I.Semantics.Vocabulary
  ( endpointContextNeed
  , endpointContextSituation
  , endpointContextStrategy
  , endpointNeedDriver
  , endpointNeedObjective
  , endpointStrategyAction
  , endpointStrategyDriver
  , endpointStrategyKeyResult
  , endpointStrategyObjective
  , endpointStrategyPrinciple
  , endpointVisionObjective
  , situationAnchorEndpoints
  , tokenAnchors
  , tokenContributesTo
  , tokenGrounds
  , tokenGuides
  , tokenIsConstitutedBy
  , tokenOrients
  , tokenSubstantiates
  , tokenSurfaces
  , familyCollectiveStrategyRealization
  , roleCollectiveParticipant
  , roleCollectiveTarget
  , completenessOpen
  , completenessClosed
  ) where

import O2I.Core.Contract
  ( CoreParticipantCompleteness
  , CoreQualifiedEndpointId
  , CoreRelationToken
  , CoreStructuredPropositionFamilyId
  , CoreStructuredPropositionRoleId
  )
import qualified O2I.Core.Contract.Generated as Generated
import O2I.Core.Contract.Internal
  ( CoreParticipantCompleteness(..)
  , CoreQualifiedEndpointId(..)
  , CoreRelationToken(..)
  , CoreStructuredPropositionFamilyId(..)
  , CoreStructuredPropositionRoleId(..)
  )

endpointContextNeed :: CoreQualifiedEndpointId
endpointContextNeed =
  CoreQualifiedEndpointId Generated.GeneratedEndpointContextNeed

endpointContextSituation :: CoreQualifiedEndpointId
endpointContextSituation =
  CoreQualifiedEndpointId Generated.GeneratedEndpointContextSituation

endpointContextStrategy :: CoreQualifiedEndpointId
endpointContextStrategy =
  CoreQualifiedEndpointId Generated.GeneratedEndpointContextStrategy

endpointNeedDriver :: CoreQualifiedEndpointId
endpointNeedDriver =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveNeedDriver

endpointNeedObjective :: CoreQualifiedEndpointId
endpointNeedObjective =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveNeedObjective

endpointStrategyAction :: CoreQualifiedEndpointId
endpointStrategyAction =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveStrategyAction

endpointStrategyDriver :: CoreQualifiedEndpointId
endpointStrategyDriver =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveStrategyDriver

endpointStrategyKeyResult :: CoreQualifiedEndpointId
endpointStrategyKeyResult =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveStrategyKeyResult

endpointStrategyObjective :: CoreQualifiedEndpointId
endpointStrategyObjective =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveStrategyObjective

endpointStrategyPrinciple :: CoreQualifiedEndpointId
endpointStrategyPrinciple =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveStrategyPrinciple

endpointVisionObjective :: CoreQualifiedEndpointId
endpointVisionObjective =
  CoreQualifiedEndpointId Generated.GeneratedEndpointPrimitiveVisionObjective

situationAnchorEndpoints :: [CoreQualifiedEndpointId]
situationAnchorEndpoints =
  [ CoreQualifiedEndpointId
      Generated.GeneratedEndpointSituationAnchorBusinessCapability
  , CoreQualifiedEndpointId
      Generated.GeneratedEndpointSituationAnchorBusinessObject
  , CoreQualifiedEndpointId
      Generated.GeneratedEndpointSituationAnchorBusinessProcess
  , CoreQualifiedEndpointId
      Generated.GeneratedEndpointSituationAnchorValueStream
  ]

tokenAnchors :: CoreRelationToken
tokenAnchors = CoreRelationToken Generated.GeneratedTokenAnchors

tokenContributesTo :: CoreRelationToken
tokenContributesTo = CoreRelationToken Generated.GeneratedTokenContributesTo

tokenGrounds :: CoreRelationToken
tokenGrounds = CoreRelationToken Generated.GeneratedTokenGrounds

tokenGuides :: CoreRelationToken
tokenGuides = CoreRelationToken Generated.GeneratedTokenGuides

tokenIsConstitutedBy :: CoreRelationToken
tokenIsConstitutedBy = CoreRelationToken Generated.GeneratedTokenIsConstitutedBy

tokenOrients :: CoreRelationToken
tokenOrients = CoreRelationToken Generated.GeneratedTokenOrients

tokenSubstantiates :: CoreRelationToken
tokenSubstantiates = CoreRelationToken Generated.GeneratedTokenSubstantiates

tokenSurfaces :: CoreRelationToken
tokenSurfaces = CoreRelationToken Generated.GeneratedTokenSurfaces

familyCollectiveStrategyRealization :: CoreStructuredPropositionFamilyId
familyCollectiveStrategyRealization =
  CoreStructuredPropositionFamilyId
    Generated.GeneratedFamilyCollectiveStrategyRealization

roleCollectiveParticipant :: CoreStructuredPropositionRoleId
roleCollectiveParticipant =
  CoreStructuredPropositionRoleId
    Generated.GeneratedRoleCollectiveStrategyRealizationRoleParticipant

roleCollectiveTarget :: CoreStructuredPropositionRoleId
roleCollectiveTarget =
  CoreStructuredPropositionRoleId
    Generated.GeneratedRoleCollectiveStrategyRealizationRoleTarget

completenessOpen :: CoreParticipantCompleteness
completenessOpen =
  CoreParticipantCompleteness Generated.GeneratedCompletenessOpen

completenessClosed :: CoreParticipantCompleteness
completenessClosed =
  CoreParticipantCompleteness Generated.GeneratedCompletenessClosed
