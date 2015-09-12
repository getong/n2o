-module (wf_convert).
-author('Maxim Sokhatsky').
-compile(export_all).
-include_lib("n2o/include/wf.hrl").

% WF to_atom to_list to_binary

-define(IS_STRING(Term), (is_list(Term) andalso Term /= [] andalso is_integer(hd(Term)))).

to_list(L) when ?IS_STRING(L) -> L;
to_list(L) when is_list(L) -> SubLists = [inner_to_list(X) || X <- L], lists:flatten(SubLists);
to_list(A) -> inner_to_list(A).
inner_to_list(A) when is_atom(A) -> atom_to_list(A);
inner_to_list(B) when is_binary(B) -> binary_to_list(B);
inner_to_list(I) when is_integer(I) -> integer_to_list(I);
inner_to_list(L) when is_tuple(L) -> lists:flatten(io_lib:format("~p", [L]));
inner_to_list(L) when is_list(L) -> L;
inner_to_list(F) when is_float(F) -> float_to_list(F,[{decimals,9},compact]).

to_atom(A) when is_atom(A) -> A;
to_atom(B) when is_binary(B) -> to_atom(binary_to_list(B));
to_atom(I) when is_integer(I) -> to_atom(integer_to_list(I));
to_atom(F) when is_float(F) -> to_atom(float_to_list(F,[{decimals,9},compact]));
to_atom(L) when is_list(L) -> list_to_atom(binary_to_list(list_to_binary(L))).

to_binary(A) when is_atom(A) -> atom_to_binary(A,latin1);
to_binary(B) when is_binary(B) -> B;
to_binary(T) when is_tuple(T) -> term_to_binary(T);
to_binary(I) when is_integer(I) -> to_binary(integer_to_list(I));
to_binary(F) when is_float(F) -> float_to_binary(F,[{decimals,9},compact]);
to_binary(L) when is_list(L) ->  iolist_to_binary(L).

to_integer(A) when is_atom(A) -> to_integer(atom_to_list(A));
to_integer(B) when is_binary(B) -> to_integer(binary_to_list(B));
to_integer(I) when is_integer(I) -> I;
to_integer([]) -> 0;
to_integer(L) when is_list(L) -> list_to_integer(L);
to_integer(F) when is_float(F) -> round(F).

% HTML encode/decode

html_encode(L,Fun) when is_function(Fun) -> Fun(L);
html_encode(L,EncType) when is_atom(L) -> html_encode(wf:to_list(L),EncType);
html_encode(L,EncType) when is_integer(L) -> html_encode(integer_to_list(L),EncType);
html_encode(L,EncType) when is_float(L) -> html_encode(float_to_list(L,[{decimals,9},compact]),EncType);
html_encode(L, false) -> L;
html_encode(L, true) -> L;
html_encode(L, whites) -> html_encode_whites(wf:to_list(lists:flatten([L]))).
html_encode(<<>>) -> [];
html_encode([]) -> [];
html_encode([H|T]) ->
	case H of
		$< -> "&lt;" ++ html_encode(T);
		$> -> "&gt;" ++ html_encode(T);
		$" -> "&quot;" ++ html_encode(T);
		$' -> "&#39;" ++ html_encode(T);
		$& -> "&amp;" ++ html_encode(T);
		BigNum when is_integer(BigNum) andalso BigNum > 255 ->
			%% Any integers above 255 are converted to their HTML encode equivilant,
			%% Example: 7534 gets turned into &#7534;
			[$&,$# | wf:to_list(BigNum)] ++ ";" ++ html_encode(T);
		Tup when is_tuple(Tup) -> 
			throw({html_encode,encountered_tuple,Tup});
		_ -> [H|html_encode(T)]
	end.

html_encode_whites([]) -> [];
html_encode_whites([H|T]) ->
	case H of
		$\s -> "&nbsp;" ++ html_encode_whites(T);
		$\t -> "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" ++ html_encode_whites(T);
		$< -> "&lt;" ++ html_encode_whites(T);
		$> -> "&gt;" ++ html_encode_whites(T);
		$" -> "&quot;" ++ html_encode_whites(T);
		$' -> "&#39;" ++ html_encode_whites(T);
		$& -> "&amp;" ++ html_encode_whites(T);
		$\n -> "<br>" ++ html_encode_whites(T);
		_ -> [H|html_encode_whites(T)]
	end.

%% URL encode/decode

url_encode(S) -> quote_plus(S).
url_decode(S) -> unquote(S).

-define(PERCENT, 37).  % $\%
-define(FULLSTOP, 46). % $\.
-define(IS_HEX(C), ((C >= $0 andalso C =< $9) orelse
    (C >= $a andalso C =< $f) orelse
    (C >= $A andalso C =< $F))).
-define(QS_SAFE(C), ((C >= $a andalso C =< $z) orelse
    (C >= $A andalso C =< $Z) orelse
    (C >= $0 andalso C =< $9) orelse
    (C =:= ?FULLSTOP orelse C =:= $- orelse C =:= $~ orelse
        C =:= $_))).

quote_plus(Atom) when is_atom(Atom) -> quote_plus(atom_to_list(Atom));
quote_plus(Int) when is_integer(Int) -> quote_plus(integer_to_list(Int));
quote_plus(Bin) when is_binary(Bin) -> quote_plus(binary_to_list(Bin));
quote_plus(String) -> quote_plus(String, []).

quote_plus([], Acc) -> lists:reverse(Acc);
quote_plus([C | Rest], Acc) when ?QS_SAFE(C) -> quote_plus(Rest, [C | Acc]);
quote_plus([$\s | Rest], Acc) -> quote_plus(Rest, [$+ | Acc]);
quote_plus([C | Rest], Acc) -> <<Hi:4, Lo:4>> = <<C>>, quote_plus(Rest, [digit(Lo), digit(Hi), ?PERCENT | Acc]).

unquote(Binary) when is_binary(Binary) -> unquote(binary_to_list(Binary));
unquote(String) -> qs_revdecode(lists:reverse(String)).

unhexdigit(C) when C >= $0, C =< $9 -> C - $0;
unhexdigit(C) when C >= $a, C =< $f -> C - $a + 10;
unhexdigit(C) when C >= $A, C =< $F -> C - $A + 10.

qs_revdecode(S) -> qs_revdecode(S, []).
qs_revdecode([], Acc) -> Acc;
qs_revdecode([$+ | Rest], Acc) -> qs_revdecode(Rest, [$\s | Acc]);
qs_revdecode([Lo, Hi, ?PERCENT | Rest], Acc) when ?IS_HEX(Lo), ?IS_HEX(Hi) -> qs_revdecode(Rest, [(unhexdigit(Lo) bor (unhexdigit(Hi) bsl 4)) | Acc]);
qs_revdecode([C | Rest], Acc) -> qs_revdecode(Rest, [C | Acc]).

%% JavaScript encode/decode

js_escape(undefined) -> [];
js_escape(Value) when is_list(Value) -> binary_to_list(js_escape(iolist_to_binary(Value)));
js_escape(Value) -> js_escape(Value, <<>>).
js_escape(<<"\\", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "\\\\">>);
js_escape(<<"\r", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "\\r">>);
js_escape(<<"\n", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "\\n">>);
js_escape(<<"\"", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "\\\"">>);
js_escape(<<"'",Rest/binary>>,Acc) -> js_escape(Rest, <<Acc/binary, "\\'">>);
js_escape(<<"<script", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "<scr\" + \"ipt">>);
js_escape(<<"script>", Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, "scr\" + \"ipt>">>);
js_escape(<<C, Rest/binary>>, Acc) -> js_escape(Rest, <<Acc/binary, C>>);
js_escape(<<>>, Acc) -> Acc.

% JOIN

join([],_) -> [];
join([Item],_Delim) -> [Item];
join([Item|Items],Delim) -> [Item,Delim | join(Items,Delim)].

% Fast HEX

digit(0) -> $0;
digit(1) -> $1;
digit(2) -> $2;
digit(3) -> $3;
digit(4) -> $4;
digit(5) -> $5;
digit(6) -> $6;
digit(7) -> $7;
digit(8) -> $8;
digit(9) -> $9;
digit(10) -> $a;
digit(11) -> $b;
digit(12) -> $c;
digit(13) -> $d;
digit(14) -> $e;
digit(15) -> $f.

hex(Bin) -> << << (digit(A1)),(digit(A2)) >> || <<A1:4,A2:4>> <= Bin >>.
unhex(Hex) -> << << (erlang:list_to_integer([H1,H2], 16)) >> || <<H1,H2>> <= Hex >>.

io(Data)     -> iolist_to_binary(Data).
bin(Data)    -> term_to_binary(Data).
list(Data)   -> binary_to_list(term_to_binary(Data)).
format(Term) -> format(Term,application:get_env(n2o,formatter,json)).

format({Io,Eval,Data},json) -> wf:info(?MODULE,"JSON {~p,_,_}: ~tp~n",[Io,io(Eval)]),
                               jsone:encode([{t,104},{v,[[{t,100},{v,io}],
                                                         [{t,109},{v,io(Eval)}],
                                                         [{t,109},{v,list(Data)}]]}]);
format({Atom,Data},   json) -> wf:info(?MODULE,"JSON {~p,_}: ~tp~n",[Atom,list(Data)]),
                               jsone:encode([{t,104},{v,[[{t,100},{v,Atom}],
                                                         [{t,109},{v,list(Data)}]]}]);

format({Io,Eval,Data},bert) -> wf:info(?MODULE,"BERT {~p,_,_}: ~tp~n",[Io,io(Eval)]),
                               {binary,term_to_binary({Io,io(Eval),bin(Data)})};
format({bin,Data},   bert)  -> wf:info(?MODULE,"BERT {bin,_}: ~tp~n",[Data]),
                               {binary,term_to_binary({bin,Data})};
format({Atom,Data},   bert) -> wf:info(?MODULE,"BERT {~p,_}: ~tp~n",[Atom,bin(Data)]),
                               {binary,term_to_binary({Atom,bin(Data)})};
format(#ftp{}=FTP,    bert) -> wf:info(?MODULE,"BERT {ftp,_,_,_,_,_,_,_,_,_,_,_}: ~tp~n",[FTP]),
                               {binary,term_to_binary(FTP)};
format(Term,          bert) -> {binary,term_to_binary(Term)};

format(_,_)                 -> {binary,term_to_binary({error,<<>>,
                                  <<"Only JSON/BERT formatters are available.">>})}.
