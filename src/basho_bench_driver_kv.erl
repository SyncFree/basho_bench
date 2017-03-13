%% -------------------------------------------------------------------
%%
%% Copyright (c) 2014 SyncFree Consortium.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(basho_bench_driver_kv).

-export([new/1,
         run/4]).

-include("basho_bench.hrl").

-define (TIMEOUT, 5000).

-record(state,
  {
   driver,
   context
 }).

%% ====================================================================
%% API
%% ====================================================================

new(_Id) ->

    Driver = basho_bench_config:get(kv_driver,riak_kv_driver),
    ensure_module(Driver),

    %%The next line could be removed in the future.
    ensure_module(riakc_pb_socket),

    IPs = basho_bench_config:get(node_ips,["127.0.0.1"]),
    Ports = basho_bench_config:get(node_ports,[8087]),

    %%Riak-specifict. Does other systems require simmilar?
    %%- Can be moved to riak driver.
    %%-- I suggest adding all the parameters that are nncessary for the
    %%-- experiments, and deal with it later.
    HeadNodeName = basho_bench_config:get(head_node_name,'riak@127.0.0.1'),
    HeadNodeCookie = basho_bench_config:get(head_node_cookie, riak),

    EmptyCtx = Driver:init({IPs, Ports, HeadNodeName, HeadNodeCookie}),
    {ok,
     #state {
        driver = Driver,
        context = EmptyCtx
       }
    }.

run(get, KeyGen, _ValueGen, State = #state{driver = Driver, context = Context}) ->
    Table = "counter_bucket",
    Key = integer_to_list(KeyGen()),
    {ok, Context1} = Driver:start_transaction(Context),
    {{ok, Object}, Context2} = Driver:get_counter({Table, Key}, Context1),
    {ok, NewCtx} = Driver:commit_transaction(Context2),
    lager:debug("Read: ~p ~p",[Object, Key]),
    {ok, State#state{context = NewCtx }};

run(get_put, KeyGen, _ValueGen, State = #state{driver = Driver, context = Context}) ->
    Table = "counter_bucket",
    Key = integer_to_list(KeyGen()),
    {ok, Context1} = Driver:start_transaction(Context),
    {{ok, _}, Context2} = Driver:inc_counter({Table, Key},10,Context1),
    {ok, NewCtx} = Driver:commit_transaction(Context2),
    {ok, State#state{context = NewCtx}}.

ensure_module(Module) ->
    case code:which(Module) of
        non_existing ->
            ?FAIL_MSG("~s requires " ++ atom_to_list(Module) ++ " module to be available on code path.\n", [?MODULE]);
        _ ->
            ok
    end.

