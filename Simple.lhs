The Simple module implements the Normal Form function by
using a na\"{i}ve version of substitution.

> module Simple(nf,aeq) where
> import Data.List(union, (\\))
> import Lambda
> import IdInt
> import qualified Data.Map as M
> import Data.Map (Map)

The normal form is computed by repeatedly performing
substitution ($\beta$-reduction) on the leftmost redex.
Variables and abstractions are easy, but in the case of
an application we must compute the function to see if
it is an abstraction.  The function cannot be computed
with the {\tt nf} function since it could perform
non-leftmost reductions.  Instead we use the {\tt whnf}
function.

> nf :: LC IdInt -> LC IdInt
> nf e@(Var _) = e
> nf (Lam x e) = Lam x (nf e)
> nf (App f a) =
>     case whnf f of
>         Lam x b -> nf (subst x a b)
>         f' -> App (nf f') (nf a)

Compute the weak head normal form.  It is similar to computing the normal form,
but it does not reduce under $\lambda$, nor does it touch an application
that is not a $\beta$-redex.

> whnf :: LC IdInt -> LC IdInt
> whnf e@(Var _) = e
> whnf e@(Lam _ _) = e
> whnf (App f a) =
>     case whnf f of
>         Lam x b -> whnf (subst x a b)
>         f' -> App f' a

Substitution has only one interesting case, the abstraction.
For abstraction there are three cases:
if the bound variable, {\tt v}, is equal to the variable we
are replacing, {\tt x}, then we are done,
if the bound variable is in set set of free variables
of the substituted expression then there would be
an accidental capture and we rename it,
otherwise the substitution just continues.

How should the new variable be picked when doing the
renaming?  The new variable must not be in the set of
free variables of {\tt s} since this would case another
accidental capture, nor must it be among the free variables
of {\tt e'} since this could cause another accidental
capture.  Conservatively, we avoid all variables occuring
in the original {\tt b} to fulfill the second requirement.

> subst :: IdInt -> LC IdInt -> LC IdInt -> LC IdInt
> subst x s b = sub vs0 b
>  where sub _ e@(Var v) | v == x = s
>                      | otherwise = e
>        sub vs e@(Lam v e') | v == x = e
>                            | v `elem` fvs = Lam v' (sub (v':vs) e'')
>                            | otherwise = Lam v (sub (v:vs) e')
>                             where v' = newId vs
>                                   e'' = subst v (Var v') e'
>        sub vs (App f a) = App (sub vs f) (sub vs a)
>
>        fvs = freeVars s
>        vs0 = fvs `union` allVars b

(Note: updated according to Kmett's blog post
 https://www.schoolofhaskell.com/user/edwardk/bound.)

Get a variable which is not in the given set.
Do this simply by generating all variables and picking the
first not in the given set.

> newId :: [IdInt] -> IdInt
> newId vs = head ([firstBoundId .. ] \\ vs)

For alpha-equivalence, we can optimize the case where the binding variable is
the same. However, if it is not, we need to check to see if the left binding
variable is free in the body of the right Lam. If so, then the terms cannot be
alpha-equal. Otherwise, we can remember that the right one matches up with the
left.

> lookupVar :: Map IdInt IdInt -> IdInt -> IdInt
> lookupVar m x = M.findWithDefault x x m 

> aeq :: LC IdInt -> LC IdInt -> Bool
> aeq x y = aeqd M.empty x y where
>   aeqd m (Var v1) (Var v2)
>     | v1 == v2  = True
>     | otherwise = v1 == lookupVar m v2
>   aeqd m (Lam v1 e1) (Lam v2 e2)
>     | v1 == v2  = aeqd m e1 e2
>     | v1 `elem` freeVars e2 = False
>     | otherwise = aeqd (M.insert v2 v1 m) e1 e2
>   aeqd m (App a1 a2) (App b1 b2) =
>     aeqd m a1 b1 && aeqd m a2 b2
>   aeqd _ _ _ = False
