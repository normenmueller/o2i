module QualificationPublicApi where

import Data.ByteString (ByteString)
import Data.List.NonEmpty (NonEmpty)
import O2I.Core.Identity (ModelIdentity)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterCollection)
import O2I.Operation.Machine (ToolDescriptor)
import O2I.Operation.Profile (ProfileInventory)
import O2I.Operation.Qualification.Subjects (runQualificationSubjects)
import O2I.Operation.Qualification.Subjects.Machine
  ( encodeQualificationSubjectsDocument
  , qualificationSubjectsDocument
  )
import O2I.Operation.Qualification.Subjects.Request
  ( qualificationSubjectsRequest
  )
import O2I.Operation.Qualification.Subjects.Result
  ( QualificationSubjectsFailure
  )
import O2I.Operation.Qualify (runQualify)
import O2I.Operation.Qualify.Machine
  ( encodeQualifyResultDocument
  , qualifyResultDocument
  )
import O2I.Operation.Qualify.Request
  ( QualifyRequest
  , QualifyRequestDefect
  , qualifyRequest
  )
import O2I.Operation.Qualify.Result
  ( QualifyFailure
  , QualifyInternalFailure
  , foldQualifyInternalFailure
  )
import O2I.Operation.View (ViewSelector)

subjectsDocument ::
     ToolDescriptor
  -> AdapterCollection
  -> ProfileInventory
  -> InputSource
  -> ViewSelector
  -> IO (Either QualificationSubjectsFailure ByteString)
subjectsDocument tool adapters profiles model view =
  fmap
    (fmap encodeQualificationSubjectsDocument
       . qualificationSubjectsDocument tool)
    (runQualificationSubjects
       adapters
       profiles
       (qualificationSubjectsRequest model view Nothing []))

qualifyDocument ::
     ToolDescriptor
  -> AdapterCollection
  -> ProfileInventory
  -> QualifyRequest
  -> IO (Either QualifyFailure ByteString)
qualifyDocument tool adapters profiles request =
  fmap
    (fmap encodeQualifyResultDocument . qualifyResultDocument tool)
    (runQualify adapters profiles request)

validatedQualifyRequest ::
     InputSource
  -> ViewSelector
  -> NonEmpty ModelIdentity
  -> [ModelIdentity]
  -> [InputSource]
  -> Either (NonEmpty QualifyRequestDefect) QualifyRequest
validatedQualifyRequest model view strategies needs supplements =
  qualifyRequest model view Nothing strategies needs supplements

foldInternalFailure :: QualifyInternalFailure -> ()
foldInternalFailure =
  foldQualifyInternalFailure
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
    (const ())
