-module(schedule_handler).
-behaviour(cowboy_handler).

-export([init/2]).

init(Req, State) ->
    io:format("Received request for /api/schedule ~0p ~n", [Req]),
    Data = #{ <<"message">> => <<"Schema genererat!">> },
    Json = jsx:encode(Data),
    Req2 = cowboy_req:reply(
        200,
        #{ <<"content-type">> => <<"application/json">> },
        Json,
        Req
    ),
    {ok, Req2, State}.
