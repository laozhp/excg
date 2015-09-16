Nonterminals array element elements object.

Terminals '{' '}' '[' ']' string ','.

Rootsymbol element.

object -> '{' elements '}' : list_to_tuple('$2').
object -> '{' '}' : {}.

array -> '[' elements ']' : '$2'.
array -> '[' ']' : [].

elements -> element ',' elements : ['$1' | '$3'].
elements -> element : ['$1'].
elements -> ',' elements : [<<>> | '$2'].
elements -> element ',' : ['$1', <<>>].
elements -> ',' : [<<>>, <<>>].

element -> string : unicode:characters_to_binary(element(3, '$1')).
element -> array : '$1'.
element -> object : '$1'.
