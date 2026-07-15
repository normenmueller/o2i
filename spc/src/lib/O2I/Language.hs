-- | Focused facade for the O2I semantic language.
--
-- The language defines elements, context-sensitive interpretations, and typed
-- relations independently of concrete graph instances and validation stages.
module O2I.Language
  ( module O2I.Language.Element
  , Interpretation(..)
  , InterpretationCode(..)
  , InterpretationSpec
  , SomeInterpretation
  , interpretationCode
  , interpretationContext
  , interpretationPrimitive
  , interpretationWitness
  , interpretationSpec
  , interpretationCodeOf
  , interpretationIdentity
  , allInterpretations
  , lookupInterpretation
  , module O2I.Language.Relation
  ) where

import O2I.Language.Element hiding (mkContextRef, mkNodeId)
import O2I.Language.Interpretation
import O2I.Language.Relation
