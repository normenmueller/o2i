{-# LANGUAGE DataKinds #-}

module RelationalProjectionTokenMismatch where

import O2I.Language.Element
import O2I.Validation.Relational.Internal

data Scope

data FirstToken

data SecondToken

invalidTokenSwap ::
     Projection
       mode
       Scope
       ('SnocPremise
          ('SnocPremise
             'EmptyPremises
             FirstToken
             ('PrimitiveKind 'Strategy 'Action)
             ('PrimitiveKind 'Strategy 'Action))
          SecondToken
          ('PrimitiveKind 'Strategy 'Action)
          ('PrimitiveKind 'Strategy 'Action))
       row
  -> Projection
       mode
       Scope
       ('SnocPremise
          ('SnocPremise
             'EmptyPremises
             SecondToken
             ('PrimitiveKind 'Strategy 'Action)
             ('PrimitiveKind 'Strategy 'Action))
          FirstToken
          ('PrimitiveKind 'Strategy 'Action)
          ('PrimitiveKind 'Strategy 'Action))
       row
invalidTokenSwap = id
