%%%-------------------------------------------------------------------
%% @doc smartplanner_backend public API
%% @end
%%%-------------------------------------------------------------------

-module(smartplanner_backend_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    smartplanner_db:init(),
    smartplanner_backend_sup:start_link().






stop(_State) ->
    ok.

%% internal functions
