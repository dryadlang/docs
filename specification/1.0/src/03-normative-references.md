# 3 Normative References

**3.1** The following documents are indispensable for the application of this
specification. For dated references, only the cited edition applies. For
undated references, the latest edition applies.

| Reference | Title | Use in this document |
|-----------|-------|----------------------|
| RFC 2119 | Key words for use in RFCs to Indicate Requirement Levels | Normative keywords (Clause 5.1) |
| RFC 8174 | Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words | Normative keyword interpretation |
| RFC 3629 | UTF-8, a transformation format of ISO 10646 | Source-text encoding (Clause 7.1) |
| ISO/IEC 10646 | Information technology — Universal Coded Character Set (UCS) | Character repertoire |
| The Unicode Standard | Version 15.1 or later | Character properties, identifier classes |
| IEEE 754-2019 | IEEE Standard for Floating-Point Arithmetic | Number semantics (Clause 8.2.3) |
| ISO/IEC 9899:2018 | Programming languages — C | Foreign function interface ABI (Clause 16) |
| System V ABI | System V Application Binary Interface, x86-64 and ARM64 editions | Calling conventions (Clauses 16, 20) |
| ELF gABI | System V gABI, Object File Format | AOT object output (Clause 20) |
| PE/COFF | Microsoft Portable Executable and Common Object File Format | AOT object output (Clause 20) |
| ECMA-262 | ECMAScript Language Specification | Informative reference for algorithm style and grammar notation |

**3.2** The following documents are informative references. They describe the
design context of this specification but do not create conformance
requirements.

| Reference | Title |
|-----------|-------|
| DRYAD-TF-2.0 | Dryad Theoretical Foundation, version 2.0 |
| DRYAD-CONV-1.0 | Dryad Conventions, version 1.0 (superseded) |
| LLVM Language Reference Manual | LLVM IR used by the AOT pipeline |
| OpenSSL documentation | TLS backend named by the standard library |
| POSIX.1-2017 | Portable Operating System Interface |

**3.3** Where a normative reference is updated, the Dryad Language Project
MAY publish an erratum adopting the update. Until such an erratum is
published, the dated edition cited in Clause 3.1 applies.
