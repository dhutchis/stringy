%% Author: dhutchis
%% Created: Jul 25, 2012
%% Description: TODO: Add description to strutil
-module(strutil).

%%
%% Include files
%%
-include("header.hrl").

%%
%% Exported Functions
%%
-export([is_substr_of_circular_roatation/2, nstrequ/2, nstrequ/4, find_prefix_substrs/1]).

%%
%% API Functions
%%

%% @doc True if S2 is a substring of any rotation of S1
%% '$' must not be a character in either string.
%% Finds the Z values of "S2$S1rep" where S1rep is S1 with the first |S2| characters repeated.
%% If any of the Z values == |S2|, we have a match.
-spec is_substr_of_circular_roatation(string(), string()) -> boolean().

is_substr_of_circular_roatation(_S1, S2) when S2 =:= "" -> true;
is_substr_of_circular_roatation(S1, S2) when length(S2) > length(S1) -> false;
is_substr_of_circular_roatation(S1, S2) ->
	A = array:from_list(S2),
	A1 = array:set(array:size(A), $$, A),
	S1rep = front_to_back(S1, S1, length(S2)-1),
	Acom = lists:foldl(fun(C, Arr) ->
							   array:set(array:size(Arr), C, Arr)
					   end, A1, S1rep),
	Z = find_prefix_substrs(Acom),
	test_endseq(Z, length(S2), length(S2)+1, length(S2)+length(S1), 0).


test_endseq(_Z, _N, Istart, Ilast, I) when I+Istart > Ilast -> false;
test_endseq(Z, N, Istart, Ilast, I) ->
	case array:get(Istart+I, Z) of
		0 -> test_endseq(Z, N, Istart, Ilast, I+1);
		N -> true;
		_Zi ->  test_endseq(Z, N, Istart, Ilast, I+1)
	end.

%% @doc generates the Z values of the string or array
-spec find_prefix_substrs(string() | array()) -> array().
find_prefix_substrs(S) when is_list(S) -> 
	find_prefix_substrs(array:fix(array:from_list(S)));
find_prefix_substrs(S) ->
	N = array:size(S),
	Z = array:new(N), 
	find_prefix_substrs(S, Z, N, 1, 0, 0).
find_prefix_substrs(_S, Z, N, I, _L, _R) when I >= N -> Z;
find_prefix_substrs(S, Z, N, I, L, R) when I > R ->
	case nstrequ(S, 0, S, I) of
		0 -> find_prefix_substrs(S, array:set(I, 0, Z), N, I+1, L, R);
		Zi -> find_prefix_substrs(S, array:set(I, Zi, Z), N, I+1, I, I+Zi-1)
	end;
find_prefix_substrs(S, Z, N, I, L, R) -> % when I =< R
	Zprev = array:get(I-L, Z),
	Numleft = R-I+1,
	if Zprev < Numleft -> find_prefix_substrs(S, array:set(I,Zprev,Z), N, I+1, L, R);
	   true -> 
		   Rnew = R+nstrequ(S, R-I+1, S, R+1),
		   Lnew = if Rnew > R -> I;
					 true -> L
				  end,
		   find_prefix_substrs(S, array:set(I, Numleft+Rnew-R, Z), N, I+1, Lnew, Rnew)
	end.


%% @doc Returns number of characters in list equal at specified offsets
%% List version
nstrequ(S, S) when is_list(S) -> length(S);
nstrequ(S1, S2) when is_list(S1), is_list(S2) -> nstrequ(S1, S2, 0).
nstrequ([C | S1], [C | S2], N) -> nstrequ(S1, S2, N+1); % match
nstrequ([_C1 | _S1], [_C2 | _S2], N) -> N; 					% no match
nstrequ([], _, N) -> N;
nstrequ(_, [], N) -> N.
%% @doc Array version (assert I, J in bounds)
%nstrequ(A, I, A, J) -> A - max(I, J);
nstrequ(A1, I1, A2, I2) -> nstrequ(A1, I1, A2, I2, 0).
nstrequ(A1, I1, A2, I2, N) ->
	case (I1 >= array:size(A1) orelse
			  I2 >= array:size(A2) orelse
			  array:get(I1, A1) =/= array:get(I2, A2)) of
		true -> N;
		false -> nstrequ(A1, I1+1, A2, I2+1, N+1)
	end.

-ifdef(EUNIT).
nstrequ_test_() ->
	L1 = lists:foldl(fun({A, B, C}, Acc) ->
							 [?_assertEqual(A, nstrequ(B, C)) | Acc]
					 end, [], [
							   {2, "abc", "abd"},
							   {2, "ab", "ab"},
							   {2, "ab", "abb"},
							   {0, "", ""}
							  ]),
	L2 = lists:foldl(fun({A,B,C,D,E}, Acc) ->
							 [?_assertEqual(A, nstrequ(array:from_list(B), C, 
													   array:from_list(D), E)) | Acc]
					 end, L1, [
							   {2, "abc", 1, "bcd", 0},
							   {1, "ab", 1, "bcd", 0}
							  ]),
	L2.
-endif.

%%
%% Local Functions
%%

%% @doc Puts N characters at the front of Src into the back of Dst
-spec front_to_back(list(A), list(B), non_neg_integer()) -> list(A | B).

front_to_back(Dst, Src, N) -> lists:reverse(front_to_back1(lists:reverse(Dst), Src, N)).

front_to_back1(Dst, _Src, 0) -> Dst;
front_to_back1(Dst, [A | Src], N) -> front_to_back1([A | Dst], Src, N-1).

%%
%% Test Functions
%%
-ifdef(EUNIT).

front_to_back_test_() ->
	[ ?_assertEqual("abcab", front_to_back("abc", "abc", 2)),
	  ?_assertEqual("abgef", front_to_back("abgef", "blabla", 0)),
	  ?_assertEqual("abgef", front_to_back("", "abgefzzz", 5))
	].

is_substr_of_circular_roatation_test_() ->
	FailTests = [
				 ?_assertNot(is_substr_of_circular_roatation("cfmasvc", "ioc")),
				 ?_assertNot(is_substr_of_circular_roatation("hey", "hey more")),
				 ?_assertNot(is_substr_of_circular_roatation("abc", "bac")),
				 ?_assertNot(is_substr_of_circular_roatation("abc", "g"))
				],
	Strs = ["banana", "tattarrattat", "abercrombie", "", "abcd", "aaaa"],
	lists:foldl(fun(S, Acc) ->
						[gen_rotate_tests(S) | Acc]
				end, FailTests, Strs).

%% @doc Returns a list of test objects testing whether every rotation of every 
%% 		substring of Str passes `is_substr_of_circular_roatation/2`.
-spec gen_rotate_tests(string()) -> [eunit_test()].
gen_rotate_tests(Str) ->
	gen_rotate_tests(Str, Str, rotate_left(Str), [], []).

%% Tests every rotation of StrTest against StrOrig and recursively tests smaller
%% substrings by cycling more letters through a buffer, all the way down to the empty strings 
-spec gen_rotate_tests(OriginalString :: string(), OriginalRotatedReducedString :: string(),
					   RotatedReducedString :: string(), Buffer :: string(), [eunit_test()]) -> [eunit_test()].

gen_rotate_tests(_StrOrig, [], [], _Buffer, Tacc) -> Tacc;

gen_rotate_tests(StrOrig, Str2Orig, Str2Orig, Buffer, Tacc) ->
	Tacc2 = [?_assert(is_substr_of_circular_roatation(StrOrig, Str2Orig)) | Tacc],
	[TransferChar | Tmp] = lists:reverse(Str2Orig),
	Str2red = lists:reverse(Tmp),
	Buffer2 = [TransferChar | Buffer],
	
	Taccnext = [?_assert(is_substr_of_circular_roatation(StrOrig, Str2red)) | Tacc2],
	{Str2next, Buffernext} = rotateThroughBuffer(Str2red, Buffer2),
	
	gen_rotate_tests(StrOrig, Str2red, Str2next, Buffernext, Taccnext);

gen_rotate_tests(StrOrig, Str2Orig, Str2, Buffer, Tacc) ->
	Taccnext = [?_assert(is_substr_of_circular_roatation(StrOrig, Str2)) | Tacc],
	{Str2next, Buffernext} = rotateThroughBuffer(Str2, Buffer),
	gen_rotate_tests(StrOrig, Str2Orig, Str2next, Buffernext, Taccnext).

%% @doc  <- Str <- Buffer <-
rotateThroughBuffer([], Buffer) -> {[], Buffer};
rotateThroughBuffer(Str, []) -> {rotate_left(Str), []};
rotateThroughBuffer([SC | Str], [BC | Buffer]) ->
	{putAtEnd(BC, Str), putAtEnd(SC, Buffer)}.

putAtEnd(C, []) -> [C];
putAtEnd(C, List) -> lists:reverse([C | lists:reverse(List)]).

putAtEnd_test_() ->
	[
	 ?_assertEqual("abc", putAtEnd($c, "ab"))
	].

rotate_left([]) -> [];
rotate_left([C | S]) -> lists:reverse([C | lists:reverse(S)]).

-endif.