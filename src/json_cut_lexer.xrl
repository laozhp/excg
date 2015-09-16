Definitions.

WS   = [\t\n\r\s]
DATA = [^"\\{}\[\],\t\n\r\s]

Rules.

{   : {token, {'{', TokenLine}}.
}   : {token, {'}', TokenLine}}.

\[  : {token, {'[', TokenLine}}.
\]  : {token, {']', TokenLine}}.

"[^"\\]*(\\.[^"\\]*)*"  : {token, {string, TokenLine, parse_string(strip(TokenChars, TokenLen))}}.
{DATA}+(\\.{DATA}*)*    : {token, {string, TokenLine, parse_string(TokenChars)}}.

,   : {token, {',', TokenLine}}.

{WS}+   :   skip_token.

Erlang code.

strip(TokenChars,TokenLen) -> lists:sublist(TokenChars, 2, TokenLen - 2).

unescape([$\\,$\"|Cs])  -> [$\"|unescape(Cs)];
unescape([$\\,$\\|Cs])  -> [$\\|unescape(Cs)];
unescape([$\\,$/|Cs])   -> [$/|unescape(Cs)];
unescape([$\\,$b|Cs])   -> [$\b|unescape(Cs)];
unescape([$\\,$f|Cs])   -> [$\f|unescape(Cs)];
unescape([$\\,$n|Cs])   -> [$\n|unescape(Cs)];
unescape([$\\,$r|Cs])   -> [$\r|unescape(Cs)];
unescape([$\\,$t|Cs])   -> [$\t|unescape(Cs)];
unescape([$\\,$u,C0,C1,C2,C3|Cs]) ->
    C = (dehex(C0) bsl 12) bor
        (dehex(C1) bsl 8) bor
        (dehex(C2) bsl 4) bor
        dehex(C3),
    [C|unescape(Cs)];
unescape([$\\,$U,C0,C1,C2,C3,C4,C5,C6,C7|Cs]) ->
    C = (dehex(C0) bsl 28) bor
        (dehex(C1) bsl 24) bor
        (dehex(C2) bsl 20) bor
        (dehex(C3) bsl 16) bor
        (dehex(C4) bsl 12) bor
        (dehex(C5) bsl 8) bor
        (dehex(C6) bsl 4) bor
        dehex(C7),
    [C|unescape(Cs)];
unescape([C|Cs]) -> [C|unescape(Cs)];
unescape([]) -> [].

dehex(C) when C >= $0, C =< $9 -> C - $0;
dehex(C) when C >= $a, C =< $f -> C - $a + 10;
dehex(C) when C >= $A, C =< $F -> C - $A + 10.

parse_string(StringChars) ->
    unescape(StringChars).
