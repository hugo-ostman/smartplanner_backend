-module(settings_handler).
-behaviour(cowboy_handler).

-export([init/2]).


-define(allowed_origin, <<"http://localhost:8080">>).

-define(JSON, #{<<"content-type">> => <<"application/json">>,
               <<"access-control-allow-origin">> => ?allowed_origin,
               <<"access-control-allow-methods">> => <<"GET, POST, DELETE, OPTIONS">>,
               <<"access-control-allow-headers">> => <<"Content-Type, Authorization">>}).

init(Req0, State) ->
    io:format("settings ~0p~n", [cowboy_req:method(Req0)]),
    Method = cowboy_req:method(Req0),
    Path   = cowboy_req:path(Req0),

    %% Hantera preflight för CORS
    case Method of
        <<"OPTIONS">> ->
            Req1 = cowboy_req:reply(204, ?JSON, <<>>, Req0),
            {ok, Req1, State};
        _ ->
            io:format("Routing ~p ~p~n", [Method, Req0]),
             {ok, Body, Req1} = cowboy_req:read_body(Req0),
            io:format("Body: ~p~n", [Body]),
            route(Method, Path, Req1, State)
    end.

route(<<"GET">>, <<"/api/settings/public-calendar">>, Req0, State) ->
    handle_get(Req0, State);
route(<<"POST">>, <<"/api/settings/public-calendar">>, Req0, State) ->
    io:format("Handling POST for public calendar~n"),
    handle_add(Req0, State);
route(<<"DELETE">>, <<"/api/settings/public-calendar">>, Req0, State) ->
    handle_delete(Req0, State);
route(_, _, Req0, State) ->
    reply(404, #{error => <<"Not found">>}, Req0, State).

%% =========================================================
%% GET – hämta alla publika kalendrar
%% =========================================================
handle_get(Req0, State) ->
    UserId = get_user_id(Req0),
    case settings_repo:get_public_calendars(UserId) of
        {ok, Urls} ->
            reply(200, #{public_calendars => Urls}, Req0, State);
        {error, Reason} ->
            reply(500, #{error => Reason}, Req0, State)
    end.

%% =========================================================
%% POST – lägg till kalender
%% =========================================================
handle_add(Req0, State) ->
    UserId = get_user_id(Req0),
    io:format("UserId: ~p~n", [UserId]),
    case cowboy_req:read_body(Req0) of
        {ok, Body, Req1} ->
            case safe_decode(Body) of
                #{<<"url">> := Url} ->
                    case validate_url(Url) of
                        ok ->
                            case settings_repo:add_public_calendar(UserId, Url) of
                                ok -> reply(200, #{status => <<"added">>}, Req1, State);
                                {error, Reason} -> reply(500, #{error => Reason}, Req1, State)
                            end;
                        {error, Msg} -> reply(400, #{error => Msg}, Req1, State)
                    end;
                _ -> reply(400, #{error => <<"Invalid payload">>}, Req1, State)
            end;
        {error, Reason} ->
            reply(400, #{error => Reason}, Req0, State)
    end.

%% =========================================================
%% DELETE – ta bort kalender
%% =========================================================
handle_delete(Req0, State) ->
    UserId = get_user_id(Req0),
    case cowboy_req:read_body(Req0) of
        {ok, Body, Req1} ->
            case safe_decode(Body) of
                #{<<"url">> := Url} ->
                    case settings_repo:remove_public_calendar(UserId, Url) of
                        ok -> reply(200, #{status => <<"removed">>}, Req1, State);
                        {error, Reason} -> reply(500, #{error => Reason}, Req1, State)
                    end;
                _ -> reply(400, #{error => <<"Invalid payload">>}, Req1, State)
            end;
        {error, Reason} ->
            reply(400, #{error => Reason}, Req0, State)
    end.

%% =========================================================
%% Helpers
%% =========================================================
validate_url(Url) when is_binary(Url) ->
    case re:run(Url, <<"^https://">>) of
        {match, _} -> ok;
        nomatch -> {error, <<"Only HTTPS URLs allowed">>}
    end;
validate_url(_) -> {error, <<"Invalid URL">>}.

safe_decode(Body) ->
    try jsx:decode(Body, [return_maps]) of
        Map when is_map(Map) -> Map
    catch _:_ -> #{} end.

reply(Code, Map, Req0, State) ->
    Req1 = cowboy_req:reply(Code, ?JSON, jsx:encode(Map), Req0),
    {ok, Req1, State}.

%% I produktion: hämta från JWT istället
get_user_id(_Req) -> <<"user-123">>.