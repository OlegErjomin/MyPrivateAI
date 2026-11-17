% Copyright (c) 2026 BestProlog

class utils
    open core

% Pairwise merge: O(n log n) instead of O(n^2) for repeated concatenation.
predicates
    joinAll : (string8* Parts) -> string8 Result.

end class utils
