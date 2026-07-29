-- | Prepared exact macro-evidence interpretation.
--
-- Preparation is a lifecycle stage, not a query convenience. Every consumer
-- reuses the same immutable indices and precompiled claim plans.
module O2I.Validation.MacroEvidence
  ( MacroEvidenceWitness
  , PreparedMacroEvidence
  , MacroPreparationWork(..)
  , MacroEvidenceWork(..)
  , prepareMacroEvidence
  , preparedContextSemantics
  , macroEvidencePreparationWork
  , macroEvidenceIndexBuildWork
  , macroEvidenceClaims
  , macroEvidenceWitnessesIn
  , macroEvidenceWitnessesInWithWork
  , macroEvidenceWitnessesForIn
  , macroEvidenceExistsIn
  , macroEvidenceExistsInWithWork
  , macroEvidenceExistsForIn
  , collectiveMacroEvidenceFor
  , witnessPremises
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import O2I.Graph.Macro
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.MacroEvidence.Eval
import O2I.Validation.MacroEvidence.Prepare
import O2I.Validation.MacroEvidence.Types
import O2I.Validation.Relational.Index

-- | Read the exact one-time preparation work.
macroEvidencePreparationWork :: PreparedMacroEvidence -> MacroPreparationWork
macroEvidencePreparationWork = preparedMacroWork

-- | Read exact typed-index construction work for this semantic model.
macroEvidenceIndexBuildWork :: PreparedMacroEvidence -> IndexBuildWork
macroEvidenceIndexBuildWork = indexBuildWork . preparedRelationalIndex

-- | Enumerate persisted typed macrorelation claims in canonical graph order.
macroEvidenceClaims ::
     PreparedMacroEvidence -> [(RawEdge, MacroClaim RawNodeId)]
macroEvidenceClaims = preparedMacroClaims

-- | Interpret one canonical macro claim through the prepared context.
macroEvidenceWitnessesIn ::
     PreparedMacroEvidence -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
macroEvidenceWitnessesIn = preparedMacroEvidenceWitnesses

-- | Enumerate exact witnesses and claim-local work.
macroEvidenceWitnessesInWithWork ::
     PreparedMacroEvidence
  -> MacroClaim RawNodeId
  -> ([MacroEvidenceWitness], MacroEvidenceWork)
macroEvidenceWitnessesInWithWork = preparedMacroEvidenceWitnessesWithWork

-- | Select exact witnesses for one registered persisted macro claim.
macroEvidenceWitnessesForIn ::
     PreparedMacroEvidence
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> [MacroEvidenceWitness]
macroEvidenceWitnessesForIn prepared source conclusion target =
  concatMap
    (macroEvidenceWitnessesIn prepared . snd)
    (macroClaimsFor (preparedMacroFacts prepared) source conclusion target)

-- | Decide exact macro evidence without constructing witness rows.
macroEvidenceExistsIn :: PreparedMacroEvidence -> MacroClaim RawNodeId -> Bool
macroEvidenceExistsIn = preparedMacroEvidenceExists

-- | Decide exact macro evidence with truthful short-circuit work.
macroEvidenceExistsInWithWork ::
     PreparedMacroEvidence -> MacroClaim RawNodeId -> (Bool, MacroEvidenceWork)
macroEvidenceExistsInWithWork = preparedMacroEvidenceExistsWithWork

-- | Decide exact evidence for one registered persisted macro claim.
macroEvidenceExistsForIn ::
     PreparedMacroEvidence -> RawNodeId -> RelationCode -> RawNodeId -> Bool
macroEvidenceExistsForIn prepared source conclusion target =
  any
    (macroEvidenceExistsIn prepared . snd)
    (macroClaimsFor (preparedMacroFacts prepared) source conclusion target)

-- | Build the narrow contribution lookup consumed by Collective validation.
collectiveMacroEvidenceFor :: PreparedMacroEvidence -> CollectiveMacroEvidence
collectiveMacroEvidenceFor prepared =
  collectiveMacroEvidence
    (\source target ->
       macroEvidenceWitnessesForIn prepared source contributesCode target)
  where
    contributesCode = relationCode (relationSpec contributesToStrategy)

-- | Enumerate the non-empty persisted premises of one exact witness.
witnessPremises :: MacroEvidenceWitness -> NonEmpty.NonEmpty RawEdge
witnessPremises = validatedWitnessPremises
