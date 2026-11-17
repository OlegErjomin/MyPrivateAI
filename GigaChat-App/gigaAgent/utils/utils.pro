% Copyright (c) 2026 BestProlog

implement utils
    open core

% Pairwise merge: O(n log n) instead of O(n^2) for repeated concatenation.
clauses
    joinAll([]) = "".
    joinAll([P]) = P.
    joinAll([A, B | Rest]) = joinAll(pairUp([A, B | Rest])).

class predicates
    pairUp : (string8* Parts) -> string8* Merged.
clauses
    pairUp([A, B | Rest]) = [string8::concat(A, B) | pairUp(Rest)] :-
        !.
    pairUp(Parts) = Parts.

end implement utils
