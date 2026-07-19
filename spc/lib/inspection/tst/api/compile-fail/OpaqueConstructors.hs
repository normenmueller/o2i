module OpaqueConstructors where

import qualified O2I.Inspection.Adapter as Adapter
import qualified O2I.Inspection.Diagnostic as Diagnostic
import qualified O2I.Inspection.Profile as Profile
import qualified O2I.Inspection.Provenance as Provenance

forgedDescriptor :: Adapter.AdapterDescriptor
forgedDescriptor = Adapter.AdapterDescriptor undefined undefined undefined

forgedNativeVersion :: Adapter.NativeVersion
forgedNativeVersion = Adapter.NativeVersion undefined

forgedCode :: Diagnostic.DiagnosticCode
forgedCode = Diagnostic.DiagnosticCode undefined

forgedId :: Diagnostic.DiagnosticId
forgedId = Diagnostic.DiagnosticId undefined

forgedSpec :: Diagnostic.DiagnosticSpec
forgedSpec =
  Diagnostic.DiagnosticSpec
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedDiagnostic :: Diagnostic.Diagnostic
forgedDiagnostic =
  Diagnostic.Diagnostic
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined
    undefined

forgedProfileVersion :: Profile.O2IProfileVersion
forgedProfileVersion = Profile.O2IProfileVersion undefined

forgedQName :: Provenance.ExpandedQName
forgedQName = Provenance.ExpandedQName undefined undefined
