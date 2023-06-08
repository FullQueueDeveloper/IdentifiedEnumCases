import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

public struct IdentifiedEnumCasesMacro: MemberMacro {
  
  /// An enum to specificy visibility of the generated code.
  /// By default `@IdentifiedEnumCasesMacro` will not
  /// generate any visibility modifiers.
  public enum Visibility: String {
    /// The generated code will be public
    case `public`
    
    /// The generated code will be private
    case `private`
    
    /// The generated code will be internal
    case `internal`
  }
   
  public static func expansion<Declaration, Context>(
    of node: SwiftSyntax.AttributeSyntax,
    providingMembersOf declaration: Declaration,
    in context: Context) throws -> [SwiftSyntax.DeclSyntax] where Declaration : SwiftSyntax.DeclGroupSyntax, Context : SwiftSyntaxMacros.MacroExpansionContext {
      


      
      guard declaration.is(EnumDeclSyntax.self) else {
        let enumError = Diagnostic(node: node._syntaxNode, message: Diagnostics.mustBeEnum)
        context.diagnose(enumError)
        return []
      }

      guard let enumCases: [SyntaxProtocol] = declaration.memberBlock
        .children(viewMode: .fixedUp)
        .filter({ $0.kind == .memberDeclList })
        .first?
        .children(viewMode: .fixedUp)
        .filter({ $0.kind == SyntaxKind.memberDeclListItem })
        .flatMap({ $0.children(viewMode: .fixedUp).filter({ $0.kind == .enumCaseDecl })})
        .flatMap({ $0.children(viewMode: .fixedUp).filter({ $0.kind == .enumCaseElementList })})
        .flatMap({ $0.children(viewMode: .fixedUp).filter({ $0.kind == .enumCaseElement })})
      else {
        let enumError = Diagnostic(node: node._syntaxNode, message: Diagnostics.mustHaveCases)
        context.diagnose(enumError)
        return []
      }

      let caseIds: [String] = enumCases.compactMap { enumCase in
        guard let firstToken = enumCase.firstToken(viewMode: .fixedUp) else {
          return nil
        }

        guard case let .identifier(id) = firstToken.tokenKind else {
          return nil
        }

        return id
      }
      
      guard !caseIds.isEmpty else {
        let enumError = Diagnostic(node: node._syntaxNode, message: Diagnostics.mustHaveCases)
        context.diagnose(enumError)
        return []
      }
      
      let enumID = "enum ID: String, Equatable, CaseIterable {\n\(caseIds.map { "  case \($0)\n" }.joined())}"
      let idAccessor = "var id: ID {\n  switch self {\n\(caseIds.map { "  case .\($0): .\($0)\n" }.joined())  }\n}"
      
      let visibility: Visibility? = node.argument?.tokens(viewMode: .fixedUp).compactMap({ tokenSyntax in
        return Visibility(rawValue: tokenSyntax.text)
      }).first
      
      switch visibility {
      case .public:
        return [
          DeclSyntax(stringLiteral: "public \(enumID)"),
          DeclSyntax(stringLiteral: "public \(idAccessor)")
        ]
      case .private:
        return [
          DeclSyntax(stringLiteral: "private \(enumID)"),
          DeclSyntax(stringLiteral: "private \(idAccessor)")
        ]
      case .internal:
        return [
          DeclSyntax(stringLiteral: "internal \(enumID)"),
          DeclSyntax(stringLiteral: "internal \(idAccessor)")
        ]
      case nil:
        return [
          DeclSyntax(stringLiteral: enumID),
          DeclSyntax(stringLiteral: idAccessor)
        ]
      }
      
 
    }
  
  public enum Diagnostics: String, DiagnosticMessage {
    
    case mustBeEnum, mustHaveCases
    
    public var message: String {
      switch self {
      case .mustBeEnum:
        return "`@IdentifiedEnumCasesMacro` can only be applied to an `enum`"
      case .mustHaveCases:
        return "`@IdentifiedEnumCasesMacro` can only be applied to an `enum` with `case` statements"
      }
    }
    
    public var diagnosticID: MessageID {
      MessageID(domain: "IdentifiedEnumCasesMacro", id: rawValue)
    }
    
    public var severity: DiagnosticSeverity { .error }
  }
}

@main
struct MacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    IdentifiedEnumCasesMacro.self,
  ]
}
