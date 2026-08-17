-- | Deterministic uniqueness assessment of supplemental payload sets.
module O2I.Input.Internal.Set
  ( assessSupplementalInputSet
  ) where

import Data.List (sortOn)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import O2I.Input.Internal.Types

-- | Admit at most one payload of each type for one exact subject identity.
--
-- Defects are ordered by payload type, subject identity, and input ordinal.
-- Accepted inputs are retained in ordinal order. No identity binding occurs at
-- this phase.
assessSupplementalInputSet ::
     [SupplementalInput]
  -> Either (NonEmpty SupplementalInputDefect) SupplementalInputSet
assessSupplementalInputSet inputs =
  case duplicateSubjectDefects inputs of
    defect:defects -> Left (defect :| defects)
    [] ->
      Right (SupplementalInputSet (sortOn supplementalInputOrdinalOf inputs))

duplicateSubjectDefects :: [SupplementalInput] -> [SupplementalInputDefect]
duplicateSubjectDefects inputs =
  [ SupplementalSubjectCardinalityInvalidDefect
    payloadType
    subject
    first
    (second :| remaining)
  | ((payloadType, subject), ordinals) <- Map.toAscList grouped
  , let orderedOrdinals = NonEmpty.toList (NonEmpty.sort ordinals)
  , first:second:remaining <- [orderedOrdinals]
  ]
  where
    grouped =
      Map.fromListWith
        (<>)
        [ ( (supplementalInputType input, supplementalInputSubject input)
          , supplementalInputOrdinalOf input :| [])
        | input <- inputs
        ]
