{-# LANGUAGE ExplicitNamespaces #-}

-- | Exact lexical model identities at the executable composition boundary.
--
-- Core remains the identity owner. Operation deliberately projects its opaque
-- validated type and decoder so a thin executable neither depends on Core nor
-- recreates its Unicode-scalar invariant.
module O2I.Operation.Identity
  ( type ModelIdentity
  , type ModelIdentityDefect
  , lexicalModelIdentity
  , modelIdentityText
  , foldModelIdentityDefect
  ) where

import Data.Text (Text)
import O2I.Core.Identity
  ( ModelIdentity
  , ModelIdentityDefect(..)
  , modelIdentity
  , modelIdentityText
  )

-- | Validate one exact user-supplied identity without replacement or
-- normalization.
lexicalModelIdentity :: Text -> Either ModelIdentityDefect ModelIdentity
lexicalModelIdentity = modelIdentity

-- | Consume every closed lexical identity defect.
foldModelIdentityDefect ::
     result -> result -> result -> ModelIdentityDefect -> result
foldModelIdentityDefect empty nul surrogate defect =
  case defect of
    EmptyModelIdentity -> empty
    ModelIdentityContainsU0000 -> nul
    ModelIdentityContainsSurrogate -> surrogate
