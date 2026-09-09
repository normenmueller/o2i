-- | Selected-View discovery of Core-qualified Need and Strategy subjects.
--
-- Discovery reports typed selected-View subjects and projects the Core-owned
-- eligibility disposition. It neither evaluates proposals nor qualifies a
-- Need/Strategy pair.
module O2I.Operation.Qualification.Subjects
  ( runQualificationSubjects
  ) where

import O2I.Operation.Qualification.Subjects.Runtime.Internal
  ( runQualificationSubjects
  )
