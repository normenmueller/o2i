-- | Internal construction of the compiled Core contract witness.
module O2I.Core.Contract.Internal
  ( CoreContractWitness(..)
  , coreContractWitness
  , CoreContractIdentity(..)
  , coreContractIdentity
  , coreContractIdentityText
  , CoreContractVersion(..)
  , coreContractVersion
  , coreContractVersionText
  , CoreContractSha256(..)
  , coreContractSha256
  , coreContractSha256Text
  , CoreContractShapeSha256(..)
  , coreContractShapeSha256
  , coreContractShapeSha256Text
  , CoreRuleId(..)
  , coreRuleIds
  , coreRuleIdText
  , capabilityInputRuleIds
  , qualificationRuleIds
  , readinessAndAssessmentRuleIds
  , semanticsRuleIds
  , structureRuleIds
  , traceRuleIds
  , CoreCarrierCategory(..)
  , CoreCarrierCategoryKind(..)
  , coreCarrierCategoryKind
  , coreCarrierCategories
  , coreCarrierCategoryText
  , lookupCoreCarrierCategory
  , CoreO2IType(..)
  , coreO2ITypes
  , coreO2ITypeText
  , lookupCoreO2IType
  , CoreRelationToken(..)
  , coreRelationTokens
  , coreRelationTokenText
  , lookupCoreRelationToken
  , CoreQualifiedEndpointId(..)
  , coreQualifiedEndpointIds
  , coreQualifiedEndpointIdText
  , lookupCoreQualifiedEndpointId
  , CoreStructuredPropositionFamilyId(..)
  , CoreStructuredPropositionFamilyKind(..)
  , coreStructuredPropositionFamilyKind
  , coreStructuredPropositionFamilyIds
  , coreStructuredPropositionFamilyIdText
  , lookupCoreStructuredPropositionFamilyId
  , CoreStructuredPropositionRoleId(..)
  , coreStructuredPropositionRoleIds
  , coreStructuredPropositionRoleIdText
  , lookupCoreStructuredPropositionRoleId
  , CoreQualificationProposalRoleId(..)
  , coreQualificationProposalRoleIds
  , coreQualificationProposalRoleIdText
  , lookupCoreQualificationProposalRoleId
  , CoreParticipantCompleteness(..)
  , coreParticipantCompletenessValues
  , coreParticipantCompletenessIdText
  , coreParticipantCompletenessToken
  , lookupCoreParticipantCompletenessId
  , lookupCoreParticipantCompletenessToken
  , lookupCoreQualifiedEndpointFor
  , coreQualifiedEndpointCategory
  , coreQualifiedEndpointContextType
  , coreQualifiedEndpointO2IType
  , coreSemanticRelationIsCompatible
  , coreStructuredFamilyParticipantRole
  , coreStructuredFamilyParticipantEndpoint
  , coreStructuredFamilyTargetRole
  , coreStructuredFamilyTargetEndpoint
  ) where

import Data.List (find)
import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified O2I.Core.Contract.Generated as Generated

-- | Closed semantic kind of a carrier category.
data CoreCarrierCategoryKind
  = ContextCarrierCategory
  | PrimitiveCarrierCategory
  | SituationAnchorCarrierCategory
  | StructuringCarrierCategory
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Classify a compiled carrier category without comparing display text.
coreCarrierCategoryKind :: CoreCarrierCategory -> CoreCarrierCategoryKind
coreCarrierCategoryKind (CoreCarrierCategory category) =
  case category of
    Generated.GeneratedCarrierContext -> ContextCarrierCategory
    Generated.GeneratedCarrierPrimitive -> PrimitiveCarrierCategory
    Generated.GeneratedCarrierSituationAnchor -> SituationAnchorCarrierCategory
    Generated.GeneratedCarrierStructuring -> StructuringCarrierCategory

-- | Closed evaluator kind of a structured-proposition family.
--
-- The exhaustive conversion makes a newly generated family a compile-time
-- obligation instead of silently assigning it existing family semantics.
data CoreStructuredPropositionFamilyKind =
  CollectiveStrategyRealizationFamily
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Select the domain evaluator required by a compiled family.
coreStructuredPropositionFamilyKind ::
     CoreStructuredPropositionFamilyId -> CoreStructuredPropositionFamilyKind
coreStructuredPropositionFamilyKind (CoreStructuredPropositionFamilyId family) =
  case family of
    Generated.GeneratedFamilyCollectiveStrategyRealization ->
      CollectiveStrategyRealizationFamily

-- | Proof that the package was built against its compiled Core companion.
data CoreContractWitness =
  CoreContractWitness
  deriving (Eq, Show)

-- | The unique witness for the compiled Core companion.
coreContractWitness :: CoreContractWitness
coreContractWitness = CoreContractWitness

-- | Opaque Core contract identity.
newtype CoreContractIdentity =
  CoreContractIdentity Text
  deriving (Eq, Ord, Show)

-- | Project a Core contract identity to its exact text.
coreContractIdentityText :: CoreContractIdentity -> Text
coreContractIdentityText (CoreContractIdentity value) = value

-- | Identity of the compiled Core companion.
coreContractIdentity :: CoreContractIdentity
coreContractIdentity = CoreContractIdentity Generated.contractIdentity

-- | Opaque semantic version of the Core contract.
newtype CoreContractVersion =
  CoreContractVersion Text
  deriving (Eq, Ord, Show)

-- | Project a Core contract version to its exact text.
coreContractVersionText :: CoreContractVersion -> Text
coreContractVersionText (CoreContractVersion value) = value

-- | Semantic version of the compiled Core companion.
coreContractVersion :: CoreContractVersion
coreContractVersion = CoreContractVersion Generated.contractVersion

-- | Opaque SHA-256 digest over the exact Core companion bytes.
newtype CoreContractSha256 =
  CoreContractSha256 Text
  deriving (Eq, Ord, Show)

-- | Project an exact-byte Core digest to lowercase hexadecimal text.
coreContractSha256Text :: CoreContractSha256 -> Text
coreContractSha256Text (CoreContractSha256 value) = value

-- | Exact-byte digest of the compiled Core companion.
coreContractSha256 :: CoreContractSha256
coreContractSha256 = CoreContractSha256 Generated.contractSha256

-- | Opaque digest over the Core companion shape manifest.
newtype CoreContractShapeSha256 =
  CoreContractShapeSha256 Text
  deriving (Eq, Ord, Show)

-- | Project a Core shape digest to lowercase hexadecimal text.
coreContractShapeSha256Text :: CoreContractShapeSha256 -> Text
coreContractShapeSha256Text (CoreContractShapeSha256 value) = value

-- | Shape-manifest digest of the compiled Core companion.
coreContractShapeSha256 :: CoreContractShapeSha256
coreContractShapeSha256 = CoreContractShapeSha256 Generated.contractShapeSha256

-- | Opaque identity of one Core rule.
newtype CoreRuleId =
  CoreRuleId Text
  deriving (Eq, Ord, Show)

-- | Project a Core rule identity to its exact text.
coreRuleIdText :: CoreRuleId -> Text
coreRuleIdText (CoreRuleId value) = value

-- | Complete canonical Core rule catalog.
coreRuleIds :: NonEmpty CoreRuleId
coreRuleIds = CoreRuleId <$> Generated.ruleIds

-- | Complete rule partition owned by capability-input decoding and binding.
capabilityInputRuleIds :: NonEmpty CoreRuleId
capabilityInputRuleIds = CoreRuleId <$> Generated.capabilityInputRuleIds

-- | Complete rule partition owned by qualification.
qualificationRuleIds :: NonEmpty CoreRuleId
qualificationRuleIds = CoreRuleId <$> Generated.qualificationRuleIds

-- | Complete rule partition shared by readiness and assessment.
readinessAndAssessmentRuleIds :: NonEmpty CoreRuleId
readinessAndAssessmentRuleIds =
  CoreRuleId <$> Generated.readinessAndAssessmentRuleIds

-- | Complete rule partition owned by semantic validation.
semanticsRuleIds :: NonEmpty CoreRuleId
semanticsRuleIds = CoreRuleId <$> Generated.semanticsRuleIds

-- | Complete rule partition owned by structural validation.
structureRuleIds :: NonEmpty CoreRuleId
structureRuleIds = CoreRuleId <$> Generated.structureRuleIds

-- | Complete rule partition owned by trace evaluation.
traceRuleIds :: NonEmpty CoreRuleId
traceRuleIds = CoreRuleId <$> Generated.traceRuleIds

-- | Opaque category of one O2I carrier.
newtype CoreCarrierCategory =
  CoreCarrierCategory Generated.GeneratedCarrierCategory
  deriving (Eq, Ord, Show)

-- | Project a carrier category to its exact profile text.
coreCarrierCategoryText :: CoreCarrierCategory -> Text
coreCarrierCategoryText (CoreCarrierCategory value) =
  Generated.generatedCarrierCategoryText value

-- | Complete carrier-category catalog.
coreCarrierCategories :: NonEmpty CoreCarrierCategory
coreCarrierCategories =
  CoreCarrierCategory <$> Generated.generatedCarrierCategories

-- | Resolve an exact carrier category from its canonical profile text.
lookupCoreCarrierCategory :: Text -> Maybe CoreCarrierCategory
lookupCoreCarrierCategory value =
  CoreCarrierCategory <$> Generated.lookupGeneratedCarrierCategory value

-- | Opaque unqualified O2I type.
newtype CoreO2IType =
  CoreO2IType Generated.GeneratedO2IType
  deriving (Eq, Ord, Show)

-- | Project an O2I type to its exact profile text.
coreO2ITypeText :: CoreO2IType -> Text
coreO2ITypeText (CoreO2IType value) = Generated.generatedO2ITypeText value

-- | Complete unqualified O2I-type catalog.
coreO2ITypes :: NonEmpty CoreO2IType
coreO2ITypes = CoreO2IType <$> Generated.generatedO2ITypes

-- | Resolve an exact O2I type from its canonical profile text.
lookupCoreO2IType :: Text -> Maybe CoreO2IType
lookupCoreO2IType value = CoreO2IType <$> Generated.lookupGeneratedO2IType value

-- | Opaque token of one semantic relation family.
newtype CoreRelationToken =
  CoreRelationToken Generated.GeneratedRelationToken
  deriving (Eq, Ord, Show)

-- | Project a relation token to its exact text.
coreRelationTokenText :: CoreRelationToken -> Text
coreRelationTokenText (CoreRelationToken value) =
  Generated.generatedRelationTokenText value

-- | Complete relation-token catalog.
coreRelationTokens :: NonEmpty CoreRelationToken
coreRelationTokens = CoreRelationToken <$> Generated.generatedRelationTokens

-- | Resolve an exact relation token from its canonical text.
lookupCoreRelationToken :: Text -> Maybe CoreRelationToken
lookupCoreRelationToken value =
  CoreRelationToken <$> Generated.lookupGeneratedRelationToken value

-- | Opaque identity of one qualified Core endpoint.
newtype CoreQualifiedEndpointId =
  CoreQualifiedEndpointId Generated.GeneratedQualifiedEndpoint
  deriving (Eq, Ord, Show)

-- | Project a qualified-endpoint identity to its exact text.
coreQualifiedEndpointIdText :: CoreQualifiedEndpointId -> Text
coreQualifiedEndpointIdText (CoreQualifiedEndpointId value) =
  Generated.generatedQualifiedEndpointText value

-- | Complete qualified-endpoint catalog.
coreQualifiedEndpointIds :: NonEmpty CoreQualifiedEndpointId
coreQualifiedEndpointIds =
  CoreQualifiedEndpointId <$> Generated.generatedQualifiedEndpoints

-- | Resolve an exact qualified-endpoint identity from its canonical text.
lookupCoreQualifiedEndpointId :: Text -> Maybe CoreQualifiedEndpointId
lookupCoreQualifiedEndpointId value =
  CoreQualifiedEndpointId <$> Generated.lookupGeneratedQualifiedEndpoint value

-- | Opaque identity of one structured-proposition family.
newtype CoreStructuredPropositionFamilyId =
  CoreStructuredPropositionFamilyId
    Generated.GeneratedStructuredPropositionFamily
  deriving (Eq, Ord, Show)

-- | Project a structured-proposition-family identity to its exact text.
coreStructuredPropositionFamilyIdText ::
     CoreStructuredPropositionFamilyId -> Text
coreStructuredPropositionFamilyIdText (CoreStructuredPropositionFamilyId value) =
  Generated.generatedStructuredPropositionFamilyText value

-- | Complete structured-proposition-family catalog.
coreStructuredPropositionFamilyIds :: NonEmpty CoreStructuredPropositionFamilyId
coreStructuredPropositionFamilyIds =
  CoreStructuredPropositionFamilyId
    <$> Generated.generatedStructuredPropositionFamilies

-- | Resolve an exact structured-proposition-family identity.
lookupCoreStructuredPropositionFamilyId ::
     Text -> Maybe CoreStructuredPropositionFamilyId
lookupCoreStructuredPropositionFamilyId value =
  CoreStructuredPropositionFamilyId
    <$> Generated.lookupGeneratedStructuredPropositionFamily value

-- | Opaque identity of one role in a structured-proposition family.
newtype CoreStructuredPropositionRoleId =
  CoreStructuredPropositionRoleId Generated.GeneratedStructuredPropositionRole
  deriving (Eq, Ord, Show)

-- | Project a structured-proposition-role identity to its exact text.
coreStructuredPropositionRoleIdText :: CoreStructuredPropositionRoleId -> Text
coreStructuredPropositionRoleIdText (CoreStructuredPropositionRoleId value) =
  Generated.generatedStructuredPropositionRoleText value

-- | Complete structured-proposition-role catalog.
coreStructuredPropositionRoleIds :: NonEmpty CoreStructuredPropositionRoleId
coreStructuredPropositionRoleIds =
  CoreStructuredPropositionRoleId
    <$> Generated.generatedStructuredPropositionRoles

-- | Resolve an exact structured-proposition-role identity.
lookupCoreStructuredPropositionRoleId ::
     Text -> Maybe CoreStructuredPropositionRoleId
lookupCoreStructuredPropositionRoleId value =
  CoreStructuredPropositionRoleId
    <$> Generated.lookupGeneratedStructuredPropositionRole value

-- | Opaque identity of one role in a Need-qualification proposal.
newtype CoreQualificationProposalRoleId =
  CoreQualificationProposalRoleId Generated.GeneratedQualificationProposalRole
  deriving (Eq, Ord, Show)

-- | Complete Need-qualification-proposal-role catalog.
coreQualificationProposalRoleIds :: NonEmpty CoreQualificationProposalRoleId
coreQualificationProposalRoleIds =
  CoreQualificationProposalRoleId
    <$> Generated.generatedQualificationProposalRoles

-- | Project a Need-qualification-proposal role to its exact identity.
coreQualificationProposalRoleIdText :: CoreQualificationProposalRoleId -> Text
coreQualificationProposalRoleIdText (CoreQualificationProposalRoleId value) =
  Generated.generatedQualificationProposalRoleText value

-- | Resolve an exact Need-qualification-proposal-role identity.
lookupCoreQualificationProposalRoleId ::
     Text -> Maybe CoreQualificationProposalRoleId
lookupCoreQualificationProposalRoleId value =
  CoreQualificationProposalRoleId
    <$> Generated.lookupGeneratedQualificationProposalRole value

-- | Opaque participant-completeness value of a structured proposition.
newtype CoreParticipantCompleteness =
  CoreParticipantCompleteness Generated.GeneratedParticipantCompleteness
  deriving (Eq, Ord, Show)

-- | Complete participant-completeness catalog.
coreParticipantCompletenessValues :: NonEmpty CoreParticipantCompleteness
coreParticipantCompletenessValues =
  CoreParticipantCompleteness
    <$> Generated.generatedParticipantCompletenessValues

-- | Project participant completeness to its stable contract identity.
coreParticipantCompletenessIdText :: CoreParticipantCompleteness -> Text
coreParticipantCompletenessIdText (CoreParticipantCompleteness value) =
  Generated.generatedParticipantCompletenessIdText value

-- | Project participant completeness to its exact profile token.
coreParticipantCompletenessToken :: CoreParticipantCompleteness -> Text
coreParticipantCompletenessToken (CoreParticipantCompleteness value) =
  Generated.generatedParticipantCompletenessToken value

-- | Resolve participant completeness from its stable contract identity.
lookupCoreParticipantCompletenessId :: Text -> Maybe CoreParticipantCompleteness
lookupCoreParticipantCompletenessId value =
  CoreParticipantCompleteness
    <$> Generated.lookupGeneratedParticipantCompletenessId value

-- | Resolve participant completeness from its exact profile token.
lookupCoreParticipantCompletenessToken ::
     Text -> Maybe CoreParticipantCompleteness
lookupCoreParticipantCompletenessToken value =
  CoreParticipantCompleteness
    <$> Generated.lookupGeneratedParticipantCompletenessToken value

-- | Resolve one exact qualified endpoint from its structural components.
--
-- Catalog uniqueness is established by companion compilation, so a runtime
-- lookup can have at most one result.
lookupCoreQualifiedEndpointFor ::
     CoreCarrierCategory
  -> Maybe CoreO2IType
  -> CoreO2IType
  -> Maybe CoreQualifiedEndpointId
lookupCoreQualifiedEndpointFor category contextType o2iType =
  CoreQualifiedEndpointId . generatedEndpoint <$> find matches rows
  where
    rows = NonEmpty.toList Generated.generatedQualifiedEndpointRows
    matches row =
      generatedEndpointCategory row == generatedCategory
        && generatedEndpointContextType row == generatedContextType
        && generatedEndpointO2IType row == generatedType
    CoreCarrierCategory generatedCategory = category
    generatedContextType = fmap (\(CoreO2IType value) -> value) contextType
    CoreO2IType generatedType = o2iType

-- | Project the carrier category admitted by a qualified endpoint.
coreQualifiedEndpointCategory :: CoreQualifiedEndpointId -> CoreCarrierCategory
coreQualifiedEndpointCategory (CoreQualifiedEndpointId endpoint) =
  CoreCarrierCategory
    (generatedEndpointCategory
       (Generated.generatedQualifiedEndpointRow endpoint))

-- | Project the optional owning Context type of a qualified endpoint.
coreQualifiedEndpointContextType :: CoreQualifiedEndpointId -> Maybe CoreO2IType
coreQualifiedEndpointContextType (CoreQualifiedEndpointId endpoint) =
  CoreO2IType
    <$> generatedEndpointContextType
          (Generated.generatedQualifiedEndpointRow endpoint)

-- | Project the unqualified O2I type of a qualified endpoint.
coreQualifiedEndpointO2IType :: CoreQualifiedEndpointId -> CoreO2IType
coreQualifiedEndpointO2IType (CoreQualifiedEndpointId endpoint) =
  CoreO2IType
    (generatedEndpointO2IType (Generated.generatedQualifiedEndpointRow endpoint))

-- | Decide exact semantic-relation compatibility from the compiled catalog.
coreSemanticRelationIsCompatible ::
     CoreRelationToken
  -> CoreQualifiedEndpointId
  -> CoreQualifiedEndpointId
  -> Bool
coreSemanticRelationIsCompatible token source target = any matches rows
  where
    rows = NonEmpty.toList Generated.generatedSemanticRelationRows
    matches row =
      generatedRelationToken row == generatedToken
        && generatedRelationSource row == generatedSource
        && generatedRelationTarget row == generatedTarget
    CoreRelationToken generatedToken = token
    CoreQualifiedEndpointId generatedSource = source
    CoreQualifiedEndpointId generatedTarget = target

-- | Participant role admitted by one structured-proposition family.
coreStructuredFamilyParticipantRole ::
     CoreStructuredPropositionFamilyId -> CoreStructuredPropositionRoleId
coreStructuredFamilyParticipantRole (CoreStructuredPropositionFamilyId family) =
  CoreStructuredPropositionRoleId
    (generatedFamilyParticipantRole
       (Generated.generatedStructuredFamilyRow family))

-- | Qualified endpoint required for each family participant.
coreStructuredFamilyParticipantEndpoint ::
     CoreStructuredPropositionFamilyId -> CoreQualifiedEndpointId
coreStructuredFamilyParticipantEndpoint (CoreStructuredPropositionFamilyId family) =
  CoreQualifiedEndpointId
    (generatedFamilyParticipantEndpoint
       (Generated.generatedStructuredFamilyRow family))

-- | Target role admitted by one structured-proposition family.
coreStructuredFamilyTargetRole ::
     CoreStructuredPropositionFamilyId -> CoreStructuredPropositionRoleId
coreStructuredFamilyTargetRole (CoreStructuredPropositionFamilyId family) =
  CoreStructuredPropositionRoleId
    (generatedFamilyTargetRole (Generated.generatedStructuredFamilyRow family))

-- | Qualified endpoint required for the family target.
coreStructuredFamilyTargetEndpoint ::
     CoreStructuredPropositionFamilyId -> CoreQualifiedEndpointId
coreStructuredFamilyTargetEndpoint (CoreStructuredPropositionFamilyId family) =
  CoreQualifiedEndpointId
    (generatedFamilyTargetEndpoint
       (Generated.generatedStructuredFamilyRow family))

generatedEndpoint ::
     Generated.GeneratedQualifiedEndpointRow
  -> Generated.GeneratedQualifiedEndpoint
generatedEndpoint (Generated.GeneratedQualifiedEndpointRow endpoint _ _ _) =
  endpoint

generatedEndpointCategory ::
     Generated.GeneratedQualifiedEndpointRow
  -> Generated.GeneratedCarrierCategory
generatedEndpointCategory (Generated.GeneratedQualifiedEndpointRow _ category _ _) =
  category

generatedEndpointContextType ::
     Generated.GeneratedQualifiedEndpointRow -> Maybe Generated.GeneratedO2IType
generatedEndpointContextType (Generated.GeneratedQualifiedEndpointRow _ _ contextType _) =
  contextType

generatedEndpointO2IType ::
     Generated.GeneratedQualifiedEndpointRow -> Generated.GeneratedO2IType
generatedEndpointO2IType (Generated.GeneratedQualifiedEndpointRow _ _ _ o2iType) =
  o2iType

generatedRelationSource ::
     Generated.GeneratedSemanticRelationRow
  -> Generated.GeneratedQualifiedEndpoint
generatedRelationSource (Generated.GeneratedSemanticRelationRow _ source _ _) =
  source

generatedRelationTarget ::
     Generated.GeneratedSemanticRelationRow
  -> Generated.GeneratedQualifiedEndpoint
generatedRelationTarget (Generated.GeneratedSemanticRelationRow _ _ target _) =
  target

generatedRelationToken ::
     Generated.GeneratedSemanticRelationRow -> Generated.GeneratedRelationToken
generatedRelationToken (Generated.GeneratedSemanticRelationRow _ _ _ token) =
  token

generatedFamilyParticipantRole ::
     Generated.GeneratedStructuredFamilyRow
  -> Generated.GeneratedStructuredPropositionRole
generatedFamilyParticipantRole (Generated.GeneratedStructuredFamilyRow _ _ _ role _ _ _ _ _ _ _ _ _) =
  role

generatedFamilyParticipantEndpoint ::
     Generated.GeneratedStructuredFamilyRow
  -> Generated.GeneratedQualifiedEndpoint
generatedFamilyParticipantEndpoint (Generated.GeneratedStructuredFamilyRow _ _ _ _ endpoint _ _ _ _ _ _ _ _) =
  endpoint

generatedFamilyTargetRole ::
     Generated.GeneratedStructuredFamilyRow
  -> Generated.GeneratedStructuredPropositionRole
generatedFamilyTargetRole (Generated.GeneratedStructuredFamilyRow _ _ _ _ _ _ _ role _ _ _ _ _) =
  role

generatedFamilyTargetEndpoint ::
     Generated.GeneratedStructuredFamilyRow
  -> Generated.GeneratedQualifiedEndpoint
generatedFamilyTargetEndpoint (Generated.GeneratedStructuredFamilyRow _ _ _ _ _ _ _ _ endpoint _ _ _ _) =
  endpoint
