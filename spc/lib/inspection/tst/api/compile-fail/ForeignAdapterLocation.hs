module ForeignAdapterLocation where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified O2I.Inspection.Adapter as Adapter
import qualified O2I.Inspection.Input as Input
import qualified O2I.Inspection.Provenance as Provenance

foreignLocationAdapter :: Adapter.Adapter
foreignLocationAdapter =
  Adapter.Adapter
    undefined
    decodeWithForeignLocation
    undefined
    undefined
    undefined
    undefined
    undefined

decodeWithForeignLocation ::
     Input.SourceDocument
  -> Adapter.DecodeAttempt Provenance.SourceLocation () ()
decodeWithForeignLocation _ =
  Adapter.DecodeUnavailable
    (Adapter.DecodeUnavailableObservation Adapter.EncodingNotObserved)
    (Provenance.Located undefined () :| [])
