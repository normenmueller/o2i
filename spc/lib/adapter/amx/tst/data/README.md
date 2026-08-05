# AMX Test Contract

## Native-Valid Versus Inspectable

The smallest native-valid AMX document is safe UTF-8 XML with root QName
`{http://www.archimatetool.com/archimate}model` and native `version="5.0.0"`.
It may contain no O2I profile, View, or model declarations because Decode
establishes only the native binding.

The smallest inspectable O2I scope additionally has exactly one selected View,
one direct root `o2i.profile="0.3"` property, and at least one directly
presented O2I candidate or admitted O2I relationship occurrence. An empty View
passes View resolution but fails Profile with `o2i.inspection.scope.empty`.
It can never produce an accidentally successful inspection without O2I content.

## Fixture Provenance

Files below `invalid/` are purpose-built negative inputs. They do not claim
Archi producer provenance. A valid reference file belongs below `valid/` only
after its Archi 5.9.0 origin, exact bytes, SHA-256, native version, profile,
stable View IDs, and expected projection have been independently recorded.

`mdl/o2i.archimate` is exercised only as a repository integration input.

## Executable Catalogue

The package test suite covers Decode safety and binding, independently selected View scopes, View-reference integrity, the complete typed model-root policy, reached-only profile defects, candidacy, metadata, notation, contextualization, Context Ownership, membership, relation projection, layout non-semantics, repeated occurrence provenance, deterministic reporting, closed defect and relation catalogs, API opacity, package licensing, and repository integration through the existing Inspection stages.
