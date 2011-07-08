{-# LANGUAGE DeriveFunctor  #-}

module Haskell 
where

type Variable = String
type Constructor = String


data Expression = Var Variable
                | App Expression Expression
                | FullApp Variable [Expression]
                | Sat Expression (Contract Expression) -- e `satisfies` c --> True iff e \in c
                | CF Expression
                | BAD
                deriving (Show,Eq,Ord)
                         
fmapExpr f (Var v) = Var $ f v
fmapExpr f (App e1 e2) = App (fmapExpr f e1) (fmapExpr f e2)
fmapExpr f (FullApp v es) = FullApp (f v) $ map (fmapExpr f) es
fmapExpr f (Sat a b) = undefined
fmapExpr f (CF e) = CF (fmapExpr f e)
fmapExpr f BAD = BAD

type Program = [DefGeneral Expression]
data DefGeneral a = ContSat (ContSat a)
                  | Def (Definition a)
                  | DataType (DataType a)
                  deriving (Eq,Show,Ord,Functor)

data ContSat a = Satisfies Variable (Contract a)
               deriving (Show,Eq,Ord,Functor)
               
data Definition a = Let Variable [Variable] a
                  | LetCase Variable [Variable] a [(Pattern,a)]
                  deriving (Show,Eq,Ord,Functor)
                  
data (DataType a) = Data Variable [(Variable,Int,Contract a)] -- Data constructors + arity + contract
                  deriving (Eq,Show,Ord,Functor)
                       
type Pattern = [Variable]

data Contract a = AppC Variable (Contract a) (Contract a) -- x : c -> c'
                | Pred Variable a  -- {x:e}
                | And (Contract a) (Contract a)
                | Or  (Contract a) (Contract a)
                | Any
                deriving (Show,Eq,Ord,Functor)

apps xs = foldl1 App xs


arities x = go x >>= \(f,i) -> [(f,i),(f++"p",i)]
  where go [] = []
        go (Def d:ds) = go2 d:go ds
          where go2 (Let f vs _) = (f,length vs)
                go2 (LetCase f vs _ _) = (f,length vs)
        go (DataType d:gs) = go2 d ++ go gs
          where go2 (Data d vac) = [(v,a) | (v,a,c) <- vac]
        go (d:ds) = go ds

appify p = map (\d -> fmap (appifyExpr a) d) p 
  where a = arities p

appifyExpr a e = go a 1 e []
  where go a count g@(App (Var v) e) acc = case lookup v a of
          Just n -> if count == n 
                    then FullApp v (e':acc)
                    else apps (App (Var $ v ++ "_ptr") e':acc)
          Nothing -> apps (App (Var v) e':acc)
          where e' = go a 1 e []
        go a count g@(App e1 e2) acc = go a (count+1) e1 (acc++[go a 1 e2 []])
        go a count (CF e) acc = CF (go a 1 e [])
        go a count (FullApp v es) acc = FullApp v $ map (\e -> go a 1 e []) es
        go a count (Sat e c) acc = Sat (go a 1 e []) c
        go a count BAD acc = BAD
        go a count (Var v) acc = Var v

substs :: [(Expression, Variable)] -> Expression -> Expression
substs [] e = e
substs ((x,y):xys) e = substs xys $ subst x y e

subst :: Expression -> Variable -> Expression -> Expression -- e[x/y]
subst x y (Var v) | v         == y = x
                  | otherwise = Var v
subst x y (App e1 e2)         = App (subst x y e1) (subst x y e2)
subst x y (FullApp f es)      = let Var x' = (subst x y (Var f)) in FullApp x' $ map (\e -> subst x y e) es
subst x y BAD                 = BAD
subst x y (CF e)              = CF (subst x y e)


substsC :: [(Expression,Variable)] -> (Contract Expression) -> (Contract Expression)
substsC [] c = c
substsC ((x,y):xys) c = substsC xys $ substC x y c


substC :: Expression -> Variable -> (Contract Expression) -> (Contract Expression)
substC x y (AppC u c1 c2) = AppC u (substC x y c1) (substC x y c2) -- TODO and if u==y?
substC x y (Pred u e)     = if u/=y then Pred u (subst x y e) else (Pred u e)
substC x y (And c1 c2)    = And (substC x y c1) (substC x y c2)
substC x y (Or c1 c2)     = Or (substC x y c1) (substC x y c2)
substC _ _ Any            = Any

ok :: Contract Expression
ok = Pred "dummy" (Var "true")

okContract 0 = ok
okContract n = AppC "okDummy" (okContract $ n-1) ok


toList (AppC _ c1 c2) = toList c1 ++ toList c2
toList x = [x]