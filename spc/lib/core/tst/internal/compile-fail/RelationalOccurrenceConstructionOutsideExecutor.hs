{-# LANGUAGE DataKinds #-}

module RelationalOccurrenceConstructionOutsideExecutor where

import O2I.Language.Element
import O2I.Validation.Relational.Types

invalidOccurrenceConstruction ::
     ProjectedOccurrence ('ContextKind 'Strategy) ('ContextKind 'Need)
invalidOccurrenceConstruction = ProjectedOccurrence undefined
