-define(TEST,true).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-type eunit_test() :: any().
-endif.

-define(NYI(X),(begin
					io:format("*** NYI ~p ~p ~p~n" ,[?MODULE, ?LINE, X]),
					exit(nyi)
				end)).
