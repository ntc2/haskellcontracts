-- -*- haskell -*-
{
module Parser where
import Data.Char
import Haskell
}

-- The second parameter, ListGeneral, is the start symbol.
%name haskell ListGeneral
%tokentype { Token }
%error { happyError }

%token
--        any   {TokenAny}
        data  {TokenData}
        '='   {TokenEquals}
        ':::' {TokenSatisfies}
        ':'   {TokenColon}
        '{'   {TokenCurlyO}
        '}'   {TokenCurlyC}
        '->'  {TokenArrow}
        con   {TokenCon $$}
        var   {TokenVar $$}
        int   {TokenInt $$}
        '|'   {TokenPipe}
        ';;'  {TokenSep}
        case  {TokenCase}
        of    {TokenOf}
        '('   {TokenParenO}
        ')'   {TokenParenC}
--        ','   {TokenComma}
        cf    {TokenCF}
        '||'  {TokenOr}
        '&&'  {TokenAnd}
%%

-- Parameterized parsers based on section 6.4.1 of the Happy manual (I
-- can't copy paste from windows to emacs right now :P).
fst(p,q)  : p q              {$1}
snd(p,q)  : p q              {$2}
list(p)   : p list(p)        {$1:$2} | {[]}
sep(p,s)  : sep1(p,s)        {$1}    | {[]} -- p's separated by s's
sep1(p,s) : p list(snd(s,p)) {$1:$2}

-- Careful: I got "Internal Happy error", not a parse error, when I
-- erroneously used sep(General,';;') here.
--
-- XXX: that was probably a bug, ask Simon M.
ListGeneral : list(fst(General,';;')) {$1}

Vars : list(var) {$1}
Named : con {Con $1} | var {Var $1} -- constructor | constant.

General : var Vars '=' Expr                  { Def $ Let $1 $2 $4 } 
        | var Vars '=' case Expr of PatExprs { Def $ LetCase $1 $2 $5 $7 }
        | var ':::' Contr                    { ContSat $ Satisfies $1 $3 }
-- XXX: do we actually support parameterized types?
        | data con Vars '=' ConDecls         { DataType $ Data $2 $5 }

Pattern  : con Vars              { ($1,$2) }
PatExpr  : '|' Pattern '->' Expr { ($2,$4) }
PatExprs : list(PatExpr)         { $1 }

-- 'undefined' here is the constructor contract.  Not currently used.
ConDecl  : con int          { ($1,$2,error "Parser.y: ConDecl: constructor contracts aren't supported.") }
ConDecls : sep(ConDecl,'|') { $1 }

Atom : Named        { Named $1 }
     | '(' Expr ')' { $2 }
Expr : Expr Atom    { $1 :@: $2 }
     | Atom         { $1 }
-- Q: there was a commented out FullApp rule.  Might be better to
-- only allow FullApp, until we add support for the "function pointer"
-- translation?
-- A: NO! FullApp is the special case, not regular app!
ContrAtom : '{' var ':' Expr '}'      { Pred $2 $4 }
          | cf                        { CF }
          | '(' Contr ')'             { $2 }
Contr : ContrAtom '&&' ContrAtom      { And $1 $3 }
      | ContrAtom '||' ContrAtom      { Or  $1 $3 }
      | var ':' ContrAtom '->' Contr  { Arr (Just $1) $3 $5 }
       -- XXX, HACK: "" becomes a fresh name in cTrans.
      |         ContrAtom '->' Contr  { Arr Nothing $1 $3 }
      | ContrAtom                     { $1 }
{
happyError :: [Token] -> a
happyError x = error $ "Parse error: " ++ show x

data Token = TokenCase
           | TokenExpr
           | TokenOf
           | TokenData
           | TokenInt Int
           | TokenPipe
           | TokenCF
           | TokenAny
           | TokenSep
           | TokenEquals
           | TokenSatisfies
           | TokenCon String -- Upper case var
           | TokenVar String -- Lower case var
           | TokenArrow
           | TokenColon
           | TokenParenO
           | TokenParenC
           | TokenCurlyO
           | TokenCurlyC
           | TokenComma
           | TokenOr
           | TokenAnd
           deriving (Eq,Show)

lexer :: String -> [Token]
lexer [] = []
lexer ('=':cs) = TokenEquals : lexer cs
lexer (':':':':':':cs) = TokenSatisfies : lexer cs
lexer (':':cs) = TokenColon : lexer cs
lexer ('|':'|':cs) = TokenOr : lexer cs
lexer ('&':'&':cs) = TokenAnd : lexer cs
lexer ('-':'>':cs) = TokenArrow : lexer cs
lexer ('{':cs) = TokenCurlyO : lexer cs
lexer ('}':cs) = TokenCurlyC : lexer cs
lexer ('(':cs) = TokenParenO : lexer cs
lexer (')':cs) = TokenParenC : lexer cs
lexer (';':';':cs) = TokenSep : lexer cs
lexer ('|':cs) = TokenPipe : lexer cs
lexer (',':cs) = TokenComma : lexer cs
lexer ('-':'-':cs) = lexer $ dropWhile (/= '\n') cs
lexer (c:cs) 
      | isSpace c = lexer cs
      | isAlpha c = lexVar (c:cs)
      | isDigit c = lexInt (c:cs)

lexInt cs = TokenInt (read num) : lexer rest
      where (num,rest) = span isDigit cs

lexVar (c:cs) = token : lexer rest where
  (var,rest) = span (\x -> isAlpha x || x == '_' || isDigit x) (c:cs)
  token = case var of
    "data" -> TokenData
    "case" -> TokenCase
    "of"   -> TokenOf
--    "Any"  -> TokenAny
    "CF"   -> TokenCF
    _      -> (if isUpper c then TokenCon else TokenVar) var

main = getContents >>= print . haskell . lexer
}
