%%%-------------------------------------------------------------------
%% @doc smartplanner_backend public API
%% @end
%%%-------------------------------------------------------------------

-module(smartplanner_backend_app).

-behaviour(application).

-export([start/2, stop/1,shutdown/0]).

start(_StartType, _StartArgs) ->
    smartplanner_db:init(),
    smartplanner_backend_sup:start_link().


stop(_State) ->
    shutdown(),
    ok.


shutdown() ->
    io:format("~n=== Shutting down SmartPlanner ===~n"),
    
    io:format("Stopping Cowboy...~n"),
    catch cowboy:stop_listener(http_listener),
    timer:sleep(100),
    
    
    io:format("Stopping applications...~n"),
    %% application:stop(smartplanner_backend),
    application:stop(cowboy),
    application:stop(cowlib),
    application:stop(ranch),
    
    %% Stop Mnesia
    io:format("Stopping Mnesia...~n"),
    mnesia:stop(),
    
    io:format("=== Shutdown complete ===~n"),
    timer:sleep(500),
    
    %% Stop node
    init:stop().

%% internal functions
