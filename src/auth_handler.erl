-module(auth_handler).
-behaviour(cowboy_handler).

-export([init/2]).
-include("user.hrl").


init(Req0, State) ->
  io:format("Hugo ~0p~n", [cowboy_req:method(Req0)]),
  case cowboy_req:method(Req0) of
       <<"OPTIONS">> ->
          Req1 = cowboy_req:reply(
            204,
            #{
              <<"access-control-allow-origin">> => <<"http://localhost:8080">>,
              <<"access-control-allow-methods">> => <<"POST, OPTIONS">>,
              <<"access-control-allow-headers">> => <<"content-type">>,
              <<"access-control-max-age">> => <<"86400">>
            },
            <<>>,
            Req0
        ),
        {ok, Req1, State};
    <<"POST">> ->
        {ok, Body, Req1} = cowboy_req:read_body(Req0),
        io:format("Body: ~p~n", [Body]),
        Data =
          case jsx:decode(Body) of
           #{<<"action">> := <<"register">>,
            <<"email">> := Mail, 
            <<"name">> := Name,
            <<"password">> := Password} ->
                io:format("Email: ~p, Name: ~p, Password: ~p~n", [Mail, Name, Password]),
                ok = smartplanner_db:add_user(Mail, Password, Name),
                #{ <<"message">> => <<"ok">> };
           #{<<"action">> := <<"login">>,
            <<"email">> := Mail, 
            <<"password">> := Password} ->
                io:format("Email: ~p, Password: ~p~n", [Mail, Password]),
                case smartplanner_db:get_user(Mail) of
                    {ok, #user{password = Password}} ->
                        #{ <<"message">> => <<"ok">> };
                    _ ->
                        #{ <<"message">> => <<"invalid_credentials">> }
                end
          end,
        Json = jsx:encode(Data),
        Req2 = cowboy_req:reply(200, #{ <<"content-type">> => <<"application/json">> }, Json, Req1),
        {ok, Req2, State}
end.






