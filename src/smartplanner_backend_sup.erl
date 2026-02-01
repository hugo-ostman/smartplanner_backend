%%%-------------------------------------------------------------------
%% @doc smartplanner_backend top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(smartplanner_backend_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    %% Definiera Cowboy router
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/api/schedule", schedule_handler, []}
        ]}
    ]),
      CowboyChild = #{
        id => cowboy_http,
        start => {cowboy, start_clear, [
            http_listener,
            [{port, 8080}],
            #{env => #{dispatch => Dispatch}}
        ]},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [cowboy]
    },
    
    SupFlags = #{strategy => one_for_one},
    {ok, {SupFlags, [CowboyChild]}}.

    
