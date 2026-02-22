-module(events_handler).
-export([init/2]).
-include("event.hrl").

init(Req, State) ->
    Method = cowboy_req:method(Req),
    Origin = cowboy_req:header(<<"origin">>, Req, <<"http://localhost:8080">>),
    AllowedOrigin = allow_origin(Origin),
    
    case Method of
        <<"OPTIONS">> ->
            Req2 = cowboy_req:reply(200, preflight_headers(AllowedOrigin), <<>>, Req),
            {ok, Req2, State};
        _ ->
            handle(Method, Req, State, AllowedOrigin)
    end.

handle(<<"GET">>, Req, State, Origin) ->
    UserId = get_user_id(Req),
    Events = get_events(UserId),
    reply(200, #{events => Events}, Req, State, Origin);

handle(<<"POST">>, Req, State, Origin) ->
    UserId = get_user_id(Req),
    {ok, Body, Req2} = cowboy_req:read_body(Req),
    Event = jsx:decode(Body, [return_maps]),
    SavedEvent = save_event(UserId, Event),
    reply(200, #{event => SavedEvent}, Req2, State, Origin);

handle(<<"PUT">>, Req, State, Origin) ->
    UserId = get_user_id(Req),
    Id = cowboy_req:binding(id, Req),
    {ok, Body, Req2} = cowboy_req:read_body(Req),
    Updates = jsx:decode(Body, [return_maps]),
    UpdatedEvent = update_event(UserId, Id, Updates),
    reply(200, #{event => UpdatedEvent}, Req2, State, Origin);

handle(<<"DELETE">>, Req, State, Origin) ->
    UserId = get_user_id(Req),
    Id = cowboy_req:binding(id, Req),
    delete_event(UserId, Id),
    reply(200, #{ok => true}, Req, State, Origin).


  

get_user_id(Req) ->
    Token = parse_token(Req),
    case smartplanner_db:get_user_id_by_token(Token) of
        {ok, UserId} -> UserId;
        {error, not_found} -> undefined
    end.

parse_token(Req) ->
    Auth = cowboy_req:header(<<"authorization">>, Req, <<>>),
    case Auth of
        <<"Bearer ", Token/binary>> -> Token;
        _ -> undefined
    end.

reply(Status, Body, Req, State, Origin) ->
    Req2 = cowboy_req:reply(
        Status,
        cors_headers(Origin),
        jsx:encode(Body),
        Req
    ),
    {ok, Req2, State}.

cors_headers(Origin) ->
    #{
        <<"access-control-allow-origin">> => Origin,
        <<"content-type">> => <<"application/json">>
    }.

preflight_headers(Origin) ->
    #{
        <<"access-control-allow-origin">> => Origin,
        <<"access-control-allow-methods">> => <<"GET, POST, PUT, DELETE, OPTIONS">>,
        <<"access-control-allow-headers">> => <<"Content-Type, Authorization">>,
        <<"access-control-max-age">> => <<"86400">>
    }.

allow_origin(<<"http://localhost:8080">>) -> <<"http://localhost:8080">>;
allow_origin(<<"http://127.0.0.1:8080">>) -> <<"http://127.0.0.1:8080">>;
allow_origin(_) -> <<"http://localhost:8080">>.



%%%===================================================================
%%% Events to db
%%%===================================================================

get_events(UserId) ->
    F = fun() ->
        mnesia:match_object(#event{user_id = UserId, _ = '_'})
    end,
    {atomic, Events} = mnesia:transaction(F),
    [event_to_map(E) || E <- Events].

save_event(UserId, Event) ->
    Id = integer_to_binary(erlang:unique_integer([positive])),
    Record = #event{
        id = Id,
        user_id = UserId,
        title = maps:get(<<"title">>, Event),
        type = maps:get(<<"type">>, Event),
        date = maps:get(<<"date">>, Event),
        start_time = maps:get(<<"startTime">>, Event),
        end_time = maps:get(<<"endTime">>, Event),
        priority = maps:get(<<"priority">>, Event),
        reminder = maps:get(<<"reminder">>, Event),
        repeat = maps:get(<<"repeat">>, Event),
        notes = maps:get(<<"notes">>, Event, <<>>),
        intensity = maps:get(<<"intensity">>, Event, undefined),
        training_type = maps:get(<<"trainingType">>, Event, undefined)
    },
    F = fun() -> mnesia:write(Record) end,
    {atomic, ok} = mnesia:transaction(F),
    event_to_map(Record).

update_event(UserId, Id, Updates) ->
    F = fun() ->
        case mnesia:read(event, Id) of
            [Record] when Record#event.user_id =:= UserId ->
                Updated = Record#event{
                    title = maps:get(<<"title">>, Updates, Record#event.title),
                    type = maps:get(<<"type">>, Updates, Record#event.type),
                    date = maps:get(<<"date">>, Updates, Record#event.date),
                    start_time = maps:get(<<"startTime">>, Updates, Record#event.start_time),
                    end_time = maps:get(<<"endTime">>, Updates, Record#event.end_time),
                    priority = maps:get(<<"priority">>, Updates, Record#event.priority),
                    reminder = maps:get(<<"reminder">>, Updates, Record#event.reminder),
                    repeat = maps:get(<<"repeat">>, Updates, Record#event.repeat),
                    notes = maps:get(<<"notes">>, Updates, Record#event.notes),
                    intensity = maps:get(<<"intensity">>, Updates, Record#event.intensity),
                    training_type = maps:get(<<"trainingType">>, Updates, Record#event.training_type)
                },
                mnesia:write(Updated),
                Updated;
            _ ->
                mnesia:abort(not_found)
        end
    end,
    {atomic, Updated} = mnesia:transaction(F),
    event_to_map(Updated).

delete_event(UserId, Id) ->
    F = fun() ->
        case mnesia:read(event, Id) of
            [Record] when Record#event.user_id =:= UserId ->
                mnesia:delete({event, Id});
            _ ->
                mnesia:abort(not_found)
        end
    end,
    {atomic, ok} = mnesia:transaction(F).

event_to_map(#event{} = E) ->
    #{
        <<"id">> => E#event.id,
        <<"userId">> => E#event.user_id,
        <<"title">> => E#event.title,
        <<"type">> => E#event.type,
        <<"date">> => E#event.date,
        <<"startTime">> => E#event.start_time,
        <<"endTime">> => E#event.end_time,
        <<"priority">> => E#event.priority,
        <<"reminder">> => E#event.reminder,
        <<"repeat">> => E#event.repeat,
        <<"notes">> => E#event.notes,
        <<"intensity">> => E#event.intensity,
        <<"trainingType">> => E#event.training_type
    }.