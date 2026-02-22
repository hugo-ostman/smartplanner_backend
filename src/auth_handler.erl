-module(auth_handler).
-behaviour(cowboy_handler).

-export([init/2]).
-include("user.hrl").


init(Req0, State) ->
  io:format("Hugo ~0p~n", [cowboy_req:method(Req0)]),
   Origin = cowboy_req:header(<<"origin">>, Req0, <<"http://localhost:8080">>),
   AllowedOrigin = allow_origin(Origin),
  case cowboy_req:method(Req0) of
       <<"OPTIONS">> ->
          Req1 = cowboy_req:reply(
            204,
            #{
              <<"access-control-allow-origin">> => AllowedOrigin,
              <<"access-control-allow-methods">> => <<"POST, OPTIONS">>,
              <<"access-control-allow-headers">> => <<"Content-Type, Authorization">>,
              <<"access-control-max-age">> => <<"86400">>
            },
            <<>>,
            Req0
        ),
        {ok, Req1, State};
    <<"POST">> ->
        {ok, Body, Req1} = cowboy_req:read_body(Req0),
        io:format("Body: ~p~n", [Body]),
          case jsx:decode(Body) of
           #{<<"action">> := <<"register">>,
            <<"email">> := Mail, 
            <<"name">> := Name,
            <<"password">> := Password} ->
                io:format("Email: ~p, Name: ~p, Password: ~p~n", [Mail, Name, Password]),
                ok = smartplanner_db:add_user(Mail, Password, Name),
                HTTPStatus = 201,
                Data = #{ <<"message">> => <<"ok">> };
           #{<<"action">> := <<"login">>,
            <<"email">> := Mail, 
            <<"password">> := Password} ->
                io:format("Email: ~p, Password: ~p~n", [Mail, Password]),
               {HTTPStatus, Data} = handle_login(Mail, Password)
          end,
        Json = jsx:encode(Data),
        Headers =  #{ <<"content-type">> => <<"application/json">>,
                     <<"access-control-allow-origin">> => AllowedOrigin }, 
        Req2 = cowboy_req:reply(HTTPStatus, Headers, Json, Req1),
        {ok, Req2, State}
end.


handle_login(Mail, Password) ->
    case smartplanner_db:get_user(Mail) of
        {ok, #user{password = StoredPasswordHash, salt = _StoredSalt} = User} ->
            case password:verify(Password, StoredPasswordHash) of
                true ->
                    Token = generate_token(User),
                    {200, #{
                        <<"message">> => <<"ok">>,
                        <<"token">> => Token,
                        <<"user">> => #{
                            <<"id">> => User#user.id,
                            <<"email">> => User#user.mail,
                            <<"name">> => User#user.name
                        }
                    }};
                false ->
                    % Vänta lite för att förhindra brute force
                    timer:sleep(1000),
                    {401, #{<<"message">> => <<"invalid_credentials">>}}
            end;
        {error, not_found} ->
            % Vänta samma tid även om användaren inte finns
            % (förhindrar att man kan testa vilka emails som finns)
            timer:sleep(1000),
            {401, #{<<"message">> => <<"invalid_credentials">>}};
        {error, _Reason} ->
            {500, #{<<"message">> => <<"server_error">>}}
    end.



%
generate_token(#user{mail = Email, id = UserId}) ->
    Timestamp = erlang:system_time(second),
    Secret = "din_hemliga_nyckel_här",
    Data = io_lib:format("~s:~p:~s", [Email, Timestamp, Secret]),
    Token = base64:encode(crypto:hash(sha256, Data)),
    %% Spara token -> user_id i Mnesia
    smartplanner_db:save_token(Token, UserId),
    Token.


allow_origin(<<"http://localhost:8080">>) -> <<"http://localhost:8080">>;
allow_origin(<<"http://127.0.0.1:8080">>) -> <<"http://127.0.0.1:8080">>;
allow_origin(_) -> <<"http://localhost:8080">>.




