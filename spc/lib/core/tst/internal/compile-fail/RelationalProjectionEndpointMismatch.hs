{-# LANGUAGE DataKinds #-}

module RelationalProjectionEndpointMismatch where

import O2I.Language.Element
import O2I.Validation.Relational.Internal

data Scope

data Token

invalidEndpointShape ::
     Projection
       mode
       Scope
       ('SnocPremise
          'EmptyPremises
          Token
          ('ContextKind 'Strategy)
          ('ContextKind 'Need))
       row
  -> Projection
       mode
       Scope
       ('SnocPremise
          'EmptyPremises
          Token
          ('ContextKind 'Strategy)
          ('ContextKind 'Intervention))
       row
invalidEndpointShape = id
