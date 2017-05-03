%% -------------------------------------------------------------------
%%
%% basho_bench: Benchmarking Suite
%%
%% Copyright (c) 2009-2010 Basho Techonologies
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
-module(basho_bench_tuner).

-behaviour(gen_fsm).

%% 0 means no spec read + SL0, 1 means spec read +SL1...
-define(SML, 0).
-define(DAMP_FACTOR, 1).
%% API
-export([start_link/0]).

%% gen_server callbacks
-export([init/1, gather_stat/2, 
         linear_new_length/5,
         linear_stay/5,
         binary_search/6,
         tuner_name/0,
         handle_info/3,
         handle_event/3,
         handle_sync_event/4,
         terminate/3, code_change/4]).


-record(state, { prev_throughput, 
                 my_workers=[],
                 myself,
                 master,
                 centralized,
		 max_len,
                 %big,
                 %sml,
                 %mid,
                 inter_node,
                 inter_gather,
                 all_inter_nodes,
                 inter_range_nodes,
                 previous,
                 current,
                 num_nodes,
                 all_nodes,
                 num_dcs,
	    	 current_round,
	         inter_round,
		 master_round,
		 round_dict,
                 inter_remain,
		 master_remain,
                 sum_throughput = 0
               }).

-include("basho_bench.hrl").

%% ====================================================================
%% API
%% ====================================================================

start_link() ->
    Name = tuner_name(), 
    lager:warning("Tuner name is ~w", [Name]),
    gen_fsm:start_link({local, Name}, ?MODULE, [Name], []).

%% ====================================================================
%% gen_server callbacks
%% ====================================================================

init([Name]) ->
    lager:warning("In init!!"),
    Myself = Name, 
    Centralized = basho_bench_config:get(centralized),
    %Sml = ?SML,
    %Big = ?BIG,
    %Mid = Sml,
    %PrevThroughput = dict:new(), %lists:foldl(fun(N, D) ->
               % dict:store(N, inf, D)
               % end, dict:new(), lists:seq(Sml, Big)),
    MaxLen = basho_bench_config:get(max_len),
    PrevThroughput = lists:foldl(fun(N, D) ->
                dict:store(N, inf, D)
                end, dict:new(), lists:seq(-1, MaxLen)),

    case Centralized of
        false ->
            MyWorkers = basho_bench_sup:workers(),
            {ok, gather_stat, #state{ prev_throughput=PrevThroughput,
                            myself = Myself,
                            centralized = Centralized,
                            %sml = Sml,
                            %big = Big,
                            %mid = Mid,
                            previous = -1,
                            current = 0,
                            num_nodes=1,
                            current_round=1,
			    inter_round=1,
			    master_round=1,
                            master_remain=1,
			    inter_remain=1,
			    max_len=MaxLen,
                            my_workers = MyWorkers,
                            all_nodes = [],
                            sum_throughput = 0}};
        true ->
            AllNodes = basho_bench_config:get(all_nodes),
            {ok, Device} = file:open("../../script/num_dcs", [read]),
            {ok, Line} = file:read_line(Device),
            NumDc = erlang:list_to_integer(Line--"\n"),
            NodesPerDc = length(AllNodes) div NumDc,
            AllTuners = [ list_to_atom( get_ip(atom_to_list(Node), []) ++"@auto_tuner") || Node <- AllNodes],
            RealNode = get_real_node(),
            MyIndex = index_of(RealNode, AllNodes, 1),
            MyInterIndex = ((MyIndex-1) div NodesPerDc * NodesPerDc) +1,
            InterNode = atom_to_list(lists:nth(MyInterIndex, AllNodes)),
            MyInterNode = {list_to_atom("micro@"++InterNode), list_to_atom(InterNode ++ "@auto_tuner")},
            AllInterNodes = lists:foldl(fun(I, AN) -> 
                                Index = 1+(I-1)*NodesPerDc,
                                N = atom_to_list(lists:nth(Index, AllNodes)),
                                [{list_to_atom("micro@"++N), lists:nth(Index, AllTuners)}|AN] end, 
                            [], lists:seq(1, NumDc)),
            InterRangeNodes = lists:foldl(fun(I, AN) ->
                                  N = atom_to_list(lists:nth(I, AllNodes)),
                                  [{list_to_atom("micro@"++N), lists:nth(I, AllTuners)}|AN] end,
                              [], lists:seq(MyInterIndex, MyInterIndex+NodesPerDc-1)), 
            NumNodes = length(AllNodes),
            [MasterNode|_] = AllNodes, 
            Master = {list_to_atom("micro@"++atom_to_list(MasterNode)), list_to_atom( atom_to_list(MasterNode) ++ "@auto_tuner")},
            InterGather = length(AllNodes) div NumDc,
            lager:warning("Master is ~w, InterNode is ~w, All nodes are ~w, inter_gather is ~w, master_gather is ~w", [Master, MyInterNode, length(AllNodes), InterGather, NumDc]),
            MyWorkers = basho_bench_sup:workers(),
	        RoundDict = dict:store(1, {0, 0}, dict:new()),
            {ok, gather_stat, #state{ prev_throughput=PrevThroughput,
                            myself = Myself,
                            master = Master,
                            num_dcs = NumDc,
			    max_len=MaxLen,
                            my_workers=MyWorkers,
                            inter_node=MyInterNode,
                            all_inter_nodes=AllInterNodes,
                            inter_range_nodes=InterRangeNodes,
                            inter_gather=InterGather,
                            centralized = Centralized,
                            num_nodes=NumNodes,
                            previous = -1,
			    master_remain=NumDc,
			    inter_remain=length(AllNodes) div NumDc,
                            current = 0,
                            current_round=1,
			    inter_round=1,
			    master_round=1,
                            round_dict=RoundDict,
                            all_nodes = AllTuners,
                            sum_throughput = 0}}
    end.

index_of(Node, [Node|_], Index) ->
    Index;
index_of(Node, [_|Rest], Index) ->
    index_of(Node, Rest, Index+1).

get_real_node() ->
    list_to_atom((remove(atom_to_list(node())))).

remove([64|T]) ->
    T;
remove([_H|T]) ->
    remove(T).

gather_stat({master_gather, MasterRound, Throughput}, State=#state{master_remain=MasterRemain, centralized=true, 
                prev_throughput=PrevTh, master_round=MasterRound, round_dict=RoundDict, max_len=MaxLen, 
                num_dcs=NumDcs, sum_throughput=SumThroughput, all_inter_nodes=AllInterNodes,  previous=Prev, current=Current}) ->
    %lager:warning("Master ~w  Received ~w for round ~w, remaining ~w", [node(), Throughput, MasterRound, MasterRemain]),
    case MasterRemain of
        1 ->
            SumThroughput1 = SumThroughput + Throughput,
            %{S1, B1, NewLength, PrevTh1} = get_new_length(PrevTh, Sml, Big, Mid, SumThroughput1),
            {Current1, PrevTh1} = linear_stay(Prev, Current, PrevTh, SumThroughput1, MaxLen),
            %{Current1, PrevTh1} = linear_new_length(Prev, Current, PrevTh, SumThroughput1),
            lager:warning("Master ~w Centralized: Previous length is ~w, current length is ~w, all inter nodes ~w", [node(), Prev, Current1, AllInterNodes]),
            lists:foreach(fun({Node, Tuner}) -> rpc:cast(Node, gen_fsm, send_event, [Tuner, {inter_new_length, Current1}]) end, AllInterNodes),
            {Prev1, Current2} = case Current1 of Current -> {Prev, Current}; _ -> {Current, Current1} end,
            ets:insert(stat, {{auto_tune, MasterRound}, {Prev, dict:fetch(Prev, PrevTh1), Current, SumThroughput1, Current1}}),
            case dict:find(MasterRound+1, RoundDict) of
                {ok, {Sum, Replied}} ->
                    {next_state, gather_stat, State#state{master_remain=NumDcs-Replied, sum_throughput=Sum,
                        previous=Prev1, current=Current2, prev_throughput=PrevTh1, master_round=MasterRound+1}};
                error ->
                    {next_state, gather_stat, State#state{master_remain=NumDcs, sum_throughput=0,
                        previous=Prev1, current=Current2, prev_throughput=PrevTh1, master_round=MasterRound+1}}
            end;
        _ ->
            {next_state, gather_stat, State#state{master_remain=MasterRemain-1, sum_throughput=SumThroughput+Throughput}}
      end;
gather_stat({master_gather, Round, Throughput}, State=#state{centralized=true, 
                master_round=MasterRound, round_dict=_RoundDict, num_dcs=NumDcs}) ->
    lager:warning("Received here!!?? Current round is ~w, proceeding to ~w", [MasterRound, Round]),
    case Round > MasterRound of
        true ->
            %RoundDict1 = dict:update(Round, fun({RSum, RCount}) -> {RSum+Throughput, RCount+1} end, {0,0}, RoundDict)  ,
            %{next_state, gather_stat, State#state{round_dict=RoundDict1}};
	    {next_state, gather_stat, State#state{master_remain=NumDcs-1, sum_throughput=Throughput, master_round=Round}};
        false ->
	    {next_state, gather_stat, State}
    end;

gather_stat({inter_gather, InterRound, Throughput}, State=#state{inter_remain=InterRemain, centralized=true, 
                inter_round=InterRound, inter_gather=InterGather, 
                master=Master, sum_throughput=SumThroughput}) ->
    %lager:warning("Inter ~w  Received ~w for round ~w, remaining ~w", [node(), Throughput, InterRound, InterRemain]),
    case InterRemain of
        1 ->
            SumThroughput1 = SumThroughput + Throughput,
    	    lager:warning("Inter ~w sending ~w to master ~w", [node(), SumThroughput1, Master]),
            %{S1, B1, NewLength, PrevTh1} = get_new_length(PrevTh, Sml, Big, Mid, SumThroughput1),
            %{Current1, PrevTh1} = linear_new_length(Prev, Current, PrevTh, SumThroughput1),
            {MNode, MTuner} = Master,
            rpc:cast(MNode, gen_fsm, send_event, [MTuner, {master_gather, InterRound, SumThroughput1}]),
            {next_state, gather_stat, State#state{inter_remain=InterGather, sum_throughput=0, inter_round=InterRound+1}};
        _ ->
            {next_state, gather_stat, State#state{inter_remain=InterRemain-1, sum_throughput=SumThroughput+Throughput}}
    end;
gather_stat({inter_gather, Round, Throughput}, State=#state{centralized=true, 
                inter_round=InterRound, round_dict=_RoundDict, inter_gather=InterGather}) ->
    lager:warning("Received here!!?? Round is ~w, current round is ~w", [Round, InterRound]),
    case Round > InterRound of
        true ->
            %RoundDict1 = dict:update(Round, fun({RSum, RCount}) -> {RSum+Throughput, RCount+1} end, {0,0}, RoundDict)  ,
            %{next_state, gather_stat, State#state{round_dict=RoundDict1}};
	    {next_state, gather_stat, State#state{inter_remain=InterGather-1, sum_throughput=Throughput, inter_round=Round}};
        false ->
            true = Round < InterRound,
	    {next_state, gather_stat, State}
    end;

gather_stat({throughput, Round, Throughput}, State=#state{num_nodes=NumNodes, centralized=Centralized, 
                my_workers=MyWorkers, prev_throughput=PrevTh, current_round=CurrentRound, max_len=MaxLen, 
                sum_throughput=SumThroughput, inter_node=InterNode, previous=Prev, current=Current}) ->
    case Centralized of
        false ->
            SumThroughput = 0,
            NumNodes = 1,
            %{S1, B1, NewLength, PrevTh1} = get_new_length(PrevTh, Sml, Big, Mid, Throughput),
            {Current1, PrevTh1} = linear_stay(Prev, Current, PrevTh, Throughput, MaxLen),
            %{Current1, PrevTh1} = linear_new_length(Prev, Current, PrevTh, Throughput),
            lager:warning("Distribute: Previous length is ~w, current is ~w, next length is ~w", [Prev, Current, Current1]),
            ets:insert(stat, {{auto_tune, CurrentRound}, {Prev, dict:fetch(Prev, PrevTh1), Current, Throughput, Current1}}),
            Workers = case MyWorkers of [] -> basho_bench_sup:workers();
                                        _ -> MyWorkers
                      end,
            lists:foreach(fun(Worker) -> gen_fsm:send_event(Worker, {specula_length, Current1}) end, Workers),
            case Current of
                Current1 ->
                    {next_state, gather_stat, State#state{previous=Prev, current_round=CurrentRound+1, current=Current1, prev_throughput=PrevTh1, my_workers=Workers}};
                _ ->
                    {next_state, gather_stat, State#state{previous=Current, current_round=CurrentRound+1, current=Current1, prev_throughput=PrevTh1, my_workers=Workers}}
            end;
        true ->
    	    lager:warning("Received ~w for round ~w, sending to inter ~w", [Throughput, Round, InterNode]),
            {INode, ITuner} = InterNode,
            rpc:cast(INode, gen_fsm, send_event, [ITuner, {inter_gather, Round, Throughput}]),
            {next_state, gather_stat, State#state{current_round=CurrentRound+1}}
    end;

gather_stat({inter_new_length, NewLength} , State=#state{inter_range_nodes=InterRangeNodes}) ->
    lists:foreach(fun({Node, Tuner}) -> rpc:cast(Node, gen_fsm, send_event, [Tuner, {new_length, NewLength}]) end, InterRangeNodes),
    {next_state, gather_stat, State};

gather_stat({new_length, NewLength} , State=#state{my_workers=MyWorkers}) ->
    %lager:warning("~w received new length ~w", [node(), NewLength]),
    Workers = case MyWorkers of [] -> basho_bench_sup:workers();
                                _ -> MyWorkers
              end,
    lists:foreach(fun(Worker) -> gen_fsm:send_event(Worker, {specula_length, NewLength}) end, Workers),
    {next_state, gather_stat, State#state{my_workers=Workers}}.

handle_info(_Info, _StateName, StateData) ->
    {stop, badmsg, StateData}.

handle_event(_Event, _StateName, StateData) ->
    {stop, badmsg, StateData}.

handle_sync_event(_Event, _From, _StateName, StateData) ->
    {stop, badmsg, StateData}.

terminate(_Reason, _, _State) ->
    ok.

code_change(_OldVsn, _, State, _Extra) ->
    {ok, execute, State}.


%% ====================================================================
%% Internal functions
%% ====================================================================
linear_stay(Prev, Current, Dict, Throughput, MaxLen) ->
    Dict1 = dict:store(Current, Throughput, Dict),
    case Prev of
        -1 -> %% This is the first time!
            Current = 0,
            {1, Dict1};
        _ ->
            PrevTh = dict:fetch(Prev, Dict),
            lager:warning("Prev is ~w, prevth is ~w, curr is ~w, curr th is ~w, max len is ~w", [PrevTh, Prev, Throughput, Current, MaxLen]),
            case Throughput > PrevTh*?DAMP_FACTOR of
                true ->
                    case Current > Prev of
                        true ->
                            Next = min(Current+1, MaxLen),
			    lager:warning("Should to here, next is ~w", [Next]),
                            to_next_or_not(Current, Next, Dict1, Throughput);
                        false -> 
                            Next = max(Current-1, 0),
                            to_next_or_not(Current, Next, Dict1, Throughput)
                    end;
                false ->
                    case Current > Prev of
                        true ->
                            {max(Current-1, 0), Dict1};
                        false -> 
                            {min(Current+1, MaxLen), Dict1}
                    end
            end
    end.

to_next_or_not(Current, Next, Dict, Throughput) ->
    NextTh = dict:fetch(Next, Dict),
    case NextTh of inf -> {Next, Dict};
                   _ -> case NextTh > Throughput of
                            true -> %%Should go to next
                                {Next, Dict};
                            false -> %%Next is smaller than myself, stay!
                                {Current, Dict}
                        end
    end.

linear_new_length(Prev, Current, Dict, Throughput, MaxLen) ->
    case Prev of
        -1 -> %% This is the first time!
            lager:warning("Prev is -1, Current is 0, throughput is ~w", [Throughput]),
            Current = 0,
            {1, dict:store(0, Throughput, Dict)};
        _ ->
            PrevTh = dict:fetch(Prev, Dict),
            lager:warning("Prev is ~w, prevth is ~w, curr is ~w, curr th is ~w", [PrevTh, Prev, Throughput, Current]),
            case Throughput > PrevTh of
                true ->
                    case Current > Prev of
                        true ->
                            {min(Current+1, MaxLen), dict:store(Current, Throughput, Dict)};
                        false -> 
                            {max(Current-1, 0), dict:store(Current, Throughput, Dict)}
                    end;
                false ->
                    case Current > Prev of
                        true ->
                            {max(Current-1, 0), dict:store(Current, Throughput, Dict)};
                        false -> 
                            {min(Current+1, MaxLen), dict:store(Current, Throughput, Dict)}
                    end
            end
    end.

binary_search(Dict, Small, Big, Mid, Throughput, MaxLen) ->
    case (Big == MaxLen) and (Small == 0) and (Mid == 0) of
        true -> % First time!
            D1 = dict:store(Small, Throughput, Dict),
            {Small, Big, (Big + Small) div 2, D1};
        false ->
            Dict1 = dict:store(Mid, Throughput, Dict),
            SmallTh = dict:fetch(Small, Dict),
            %io:format("Small th is ~w, th is ~w ~n", [SmallTh, Throughput]),
	        lager:warning("Current pos is ~w, th is ~w, small th is ~w", [Mid, Throughput, SmallTh]),
            case Throughput > SmallTh of
                true ->
                    S1 = Mid,
                    M1 = (S1 + Big) div 2,
                    case M1 of 
                        Mid -> {S1, Big, Big, Dict1};
                        _ -> {S1, Big, M1, Dict1}
                    end;
                false ->
                    B1 = Mid,
                    M1 = (Small + B1) div 2,
                    case M1 of
                        Mid -> {Small, B1, Small, Dict1};
                        _ -> {Small, B1, M1, Dict1}
                    end
            end
    end.

get_ip([], Prev) ->
    lists:reverse(Prev);
get_ip([C|T], Prev) ->
    D = [C],
    case D of
        "@" -> T;
        _ -> get_ip(T, [C|Prev])
    end.

tuner_name() ->
    case basho_bench_config:get(auto_tune, false) of
        false -> false;
        true -> list_to_atom( get_ip(atom_to_list(node()), [])  ++ "@auto_tuner")
    end.
