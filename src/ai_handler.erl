-module(ai_handler).
-export([init/2]).

init(Req, State) ->
    Method = cowboy_req:method(Req),
    Origin = cowboy_req:header(<<"origin">>, Req, <<"http://localhost:8080">>),
    AllowedOrigin = allow_origin(Origin),

    case Method of
        <<"OPTIONS">> ->
            Req2 = cowboy_req:reply(200, preflight_headers(AllowedOrigin), <<>>, Req),
            {ok, Req2, State};
        <<"POST">> ->
            {ok, Body, Req2} = cowboy_req:read_body(Req),
            Data = jsx:decode(Body, [return_maps]),
            Messages = maps:get(<<"messages">>, Data),
            Events = maps:get(<<"events">>, Data),

            %% Bygg systemprompt med användarens events
            SystemPrompt = build_system_prompt(Events),

            %% Bygg meddelanden för Ollama
            OllamaMessages = [#{<<"role">> => <<"system">>, <<"content">> => SystemPrompt} | Messages],

            {ok, Response} = ollama_client:chat(<<"llama3.1:latest">>, OllamaMessages),
            Message = maps:get(<<"content">>, maps:get(<<"message">>, Response)),

            reply(200, #{message => Message}, Req2, State, AllowedOrigin);
        _ ->
            reply(405, #{error => <<"method_not_allowed">>}, Req, State, AllowedOrigin)
    end.

build_system_prompt(Events) ->
    EventList = [io_lib:format("- ~s (~s) ~s ~s-~s", [
        maps:get(<<"title">>, E),
        maps:get(<<"type">>, E),
        maps:get(<<"date">>, E),
        maps:get(<<"startTime">>, E),
        maps:get(<<"endTime">>, E)
    ]) || E <- Events],
    EventStr = list_to_binary(lists:join("\n", EventList)),
    <<"Du är en smart schemaläggningsassistent. Svara på svenska och hjälp användaren planera sin tid.\n\nAnvändarens kommande aktiviteter:\n", EventStr/binary>>.

reply(Status, Body, Req, State, Origin) ->
    Req2 = cowboy_req:reply(
        Status,
        #{
            <<"content-type">> => <<"application/json">>,
            <<"access-control-allow-origin">> => Origin
        },
        jsx:encode(Body),
        Req
    ),
    {ok, Req2, State}.

preflight_headers(Origin) ->
    #{
        <<"access-control-allow-origin">> => Origin,
        <<"access-control-allow-methods">> => <<"POST, OPTIONS">>,
        <<"access-control-allow-headers">> => <<"Content-Type, Authorization">>,
        <<"access-control-max-age">> => <<"86400">>
    }.

allow_origin(<<"http://localhost:8080">>) -> <<"http://localhost:8080">>;
allow_origin(<<"http://127.0.0.1:8080">>) -> <<"http://127.0.0.1:8080">>;
allow_origin(_) -> <<"http://localhost:8080">>.