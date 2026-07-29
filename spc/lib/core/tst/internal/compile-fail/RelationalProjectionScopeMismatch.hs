{-# LANGUAGE DataKinds #-}

module RelationalProjectionScopeMismatch where

import O2I.Language.Element
import O2I.Validation.Relational.Internal

data LocalScope

data ForeignScope

data Token

invalidScope ::
     Projection
       mode
       LocalScope
       ('SnocPremise
          'EmptyPremises
          Token
          ('ContextKind 'Strategy)
          ('ContextKind 'Need))
       row
  -> Projection
       mode
       ForeignScope
       ('SnocPremise
          'EmptyPremises
          Token
          ('ContextKind 'Strategy)
          ('ContextKind 'Need))
       row
invalidScope = id
