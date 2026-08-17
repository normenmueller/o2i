module SupplementalInputOpaqueConstructors where

import O2I.Semantics.Input

forgeDefect :: SupplementalInputDefect
forgeDefect = SupplementalInvalidUtf8Defect (supplementalInputOrdinal 0)
