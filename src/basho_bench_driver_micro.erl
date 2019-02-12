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
-module(basho_bench_driver_micro).

-export([new/1,
        terminate/2,
        get_stat/1,
        run/5,
        run/7]).

-include("basho_bench.hrl").

-define(TIMEOUT, 70000).
-define(READ_TIMEOUT, 70000).

-record(state, {worker_id,
                time,
                consistency,
                total_key,
                total_read,
                part_list,
		        my_table,
                process_time,
                expand_part_list,
                my_stat,
                hash_length,
                w_per_dc,
                my_rep_list,
                to_sleep,
                hash_dict,
                deter,
                no_rep_list,
                other_master_ids,
                dc_rep_ids,
                no_rep_ids,
                num_nodes,
                master_num,
                slave_num,
                cache_num,
                master_range,
                slave_range,
                cache_range,
                local_hot_range,
                local_hot_rate,
                remote_hot_range,
                remote_hot_rate,
                cache_hot_range,
                cache_hot_rate,
                node_id,
                tx_server,
                target_node}).

%% ====================================================================
%% API
%% ====================================================================

new(Id) ->
    %% Make sure bitcask is available
    case code:which(antidote) of
        non_existing ->
            ?FAIL_MSG("~s requires antidote to be available on code path.\n",
                      [?MODULE]);
        _ ->
            ok
    end,

    random:seed(os:timestamp()),
    %_PbPorts = basho_bench_config:get(antidote_pb_port),
    %MyNode = basho_bench_config:get(antidote_mynode),
    %Cookie = basho_bench_config:get(antidote_cookie),
    IPs = basho_bench_config:get(antidote_pb_ips),
    MasterToSleep = basho_bench_config:get(master_to_sleep),
    ToSleep = basho_bench_config:get(to_sleep),
    ProcessTime = basho_bench_config:get(process_time),
    TotalKey = basho_bench_config:get(total_key),
    TotalRead = basho_bench_config:get(total_read),
    Concurrent = basho_bench_config:get(concurrent),
    Consistency = basho_bench_config:get(consistency),
   
    MasterNum = basho_bench_config:get(master_num)*100,
    SlaveNum = basho_bench_config:get(slave_num)*100,
    CacheNum = basho_bench_config:get(cache_num)*100,

    MasterRange = basho_bench_config:get(master_range),
    SlaveRange = basho_bench_config:get(slave_range),
    CacheRange = basho_bench_config:get(cache_range),

    t = basho_bench_config:get(prob_access),

    LocalHotRange = basho_bench_config:get(local_hot_range),
    LocalHotRate = basho_bench_config:get(local_hot_rate),
    RemoteHotRange = basho_bench_config:get(remote_hot_range),
    RemoteHotRate = basho_bench_config:get(remote_hot_rate),
    CacheHotRange = basho_bench_config:get(cache_hot_range, LocalHotRange),
    CacheHotRate = basho_bench_config:get(cache_hot_rate, LocalHotRate),
    Deter = basho_bench_config:get(deter),

    TargetNode = lists:nth(((Id-1) rem length(IPs)+1), IPs),
    case Id of 1 ->
    %    case net_kernel:start(MyNode) of
    %            {ok, _} -> true = erlang:set_cookie(node(), Cookie),  %?INFO("Net kernel started as ~p\n", [node()]);
           _Result = net_adm:ping(TargetNode),
           HashFun =  rpc:call(TargetNode, hash_fun, get_hash_fun, []),
           ets:insert(load_info, {hash_fun, HashFun});
    %            {error, {already_started, _}} ->
    %                    ?INFO("Net kernel already started as ~p\n", [node()]),  ok;
    %            {error, Reason} ->
    %            ?FAIL_MSG("Failed to start net_kernel for ~p: ~p\n", [?MODULE, Reason])
    %    end;
             _ -> ok
    end,

    [{hash_fun, {_, PartList, ReplList, NumDcs}}] = ets:lookup(load_info, hash_fun),
    MyTxServer = case length(IPs) of 1 ->
                 case Id of 1 -> 
                        NameLists = lists:foldl(fun(WorkerId, Acc) -> [WorkerId|Acc]
                                end, [], lists:seq(1, Concurrent)),
                        Pids = locality_fun:get_pids(TargetNode, lists:reverse(NameLists)),
                    lists:foldl(fun(P, Acc) -> ets:insert(load_info, {Acc, P}), Acc+1 end, 1, Pids),
                    hd(Pids);
                            _ ->  [{Id, Pid}] = ets:lookup(load_info, Id),
                          Pid
            end;
        _ ->
            case Id of 1 -> timer:sleep(MasterToSleep);
                   _ -> ok
            end,
            locality_fun:get_pid(TargetNode, Id)
    end,

    %lager:info("Part list is ~w, repl list is ~w", [PartList, ReplList]),

    %[M] = [L || {N, L} <- ReplList, N == TargetNode ],
    AllNodes = [N || {N, _} <- PartList],
    NodeId = index(TargetNode, AllNodes),
    NumNodes = length(AllNodes),
    ExpandPartList = lists:flatten([L || {_, L} <- PartList]),
    HashLength = length(ExpandPartList),
    {OtherMasterIds, DcRepIds, DcNoRepIds, HashDict} = locality_fun:get_locality_list(PartList, ReplList, NumDcs, TargetNode, single_node_read),
    HashDict1 = locality_fun:replace_name_by_pid(TargetNode, dict:store(cache, TargetNode, HashDict)),
    %lager:info("NodeId is ~w, MyTxServer is  ~w, DcRepIds ~w, NoRepIds ~w, D ~w", [NodeId, MyTxServer, DcRepIds, DcNoRepIds, dict:to_list(HashDict1)]),

    %lager:info("Part list is ~w",[PartList]),
    MyTable = ets:new(my_table, [private, set]),
    {ok, #state{time={1,1,1}, worker_id=Id,
               deter = Deter,
               my_stat = {{0,0}, {0,0}, {0,0}, {0,0}},
               total_key = TotalKey,
               total_read = TotalRead,
               tx_server=MyTxServer,
               consistency=Consistency,
               part_list = PartList,
		       my_table=MyTable,
               process_time=ProcessTime,
               other_master_ids=OtherMasterIds,
               dc_rep_ids = DcRepIds,
               no_rep_ids = DcNoRepIds,
               hash_dict = HashDict1,
               to_sleep=ToSleep,
               master_num=MasterNum,
               slave_num=SlaveNum,
               cache_num=CacheNum,
               master_range=MasterRange,
               slave_range=SlaveRange,
               cache_range=CacheRange,
               local_hot_range=LocalHotRange,
               local_hot_rate=LocalHotRate,
               remote_hot_range=RemoteHotRange,
               remote_hot_rate=RemoteHotRate,
               cache_hot_range=CacheHotRange,
               cache_hot_rate=CacheHotRate,
               expand_part_list = ExpandPartList,
               hash_length = HashLength,   
               num_nodes = NumNodes,
               node_id = NodeId,
               target_node=TargetNode}}.

get_stat(#state{target_node=TargetNode, worker_id=Id, my_stat=MyStat}) ->
    {S1, S2, S3, S4} = MyStat,
    case Id of
        1 ->
            BlockStat = rpc:call(TargetNode, tx_cert_sup, get_stat, []),
            {BlockStat, [S1, S2, S3, S4]};
        _ ->
            {cleaned_up, [S1, S2, S3, S4]}
    end.

%% @doc Warehouse, District are always local.. Only choose to access local or remote objects when reading
%% objects. 
run(txn, TxnSeq, MsgId, Seed, State) ->
    run(txn, TxnSeq, MsgId, Seed, ignore, ignore, State).

run(txn, TxnSeq, MsgId, Seed, SpeculaLen, SpeculaRead, State=#state{part_list=PartList, tx_server=TxServer, deter=Deter, total_key=TotalKey, total_read = TotalRead, consistency = Consistency,
        dc_rep_ids=DcRepIds, node_id=MyNodeId,  hash_dict=HashDict, no_rep_ids=NoRepIds, 
        local_hot_rate=LocalHotRate, local_hot_range=LocalHotRange, remote_hot_rate=RemoteHotRate, remote_hot_range=RemoteHotRange,
        cache_hot_range=CacheHotRange, cache_range=CRange, cache_hot_rate=CacheHotRate,
        master_num=MNum, slave_num=SNum, master_range=MRange, slave_range=SRange})->
    random:seed(Seed),
    %StartTime = os:timestamp(),
    Add = random:uniform(3)-2,

    case gen_server:call(TxServer, {start_tx, TxnSeq}) of
        {final_abort, Info} ->
            {final_abort, Info, State};
        TxId ->
            %lager:warning("Start ~w", [TxId]),
            NumKeys = TotalKey,
            DcRepLen = length(DcRepIds),
            NoRepLen = length(NoRepIds),
            {_, WriteSet} = lists:foldl(fun(_, {Cnt, WS}) ->
                    Rand = random:uniform(10000),
                    {MyKey, KeyNode, Val} = case Rand =< MNum of
                        true -> 
                            Key = hot_or_not(1, LocalHotRange, MRange, LocalHotRate),
                            V = read_from_node(TxServer, TxId, Key, MyNodeId, MyNodeId, PartList, HashDict, SpeculaRead),
                            {Key, MyNodeId, V};
                        false -> 
                            case Rand =< MNum+SNum of
                                true ->     
                                    Key = hot_or_not(MRange+1, RemoteHotRange, SRange, RemoteHotRate),
                                    Deter = false,
                                    Rand1 = random:uniform(DcRepLen),
                                    DcNode = lists:nth(Rand1, DcRepIds),
                                    V = read_from_node(TxServer, TxId, Key, DcNode, MyNodeId, PartList, HashDict, SpeculaRead),
                                    {Key, DcNode, V};
                                false -> OtherDcNode = lists:nth(Rand rem NoRepLen +1, NoRepIds),
                                    Key = hot_or_not(MRange+SRange+1, CacheHotRange, CRange, CacheHotRate),
                                    V = read_from_node(TxServer, TxId, Key, OtherDcNode, MyNodeId, PartList, HashDict, SpeculaRead),
                                    {Key, OtherDcNode, V}
                            end
                    end,
                    case Cnt < TotalRead of
                        true -> case Consistency of
                                    si -> {Cnt+1, WS}; 
                                    ser -> {Cnt+1, dict:store({KeyNode, MyKey}, read, WS)}
                                end;
                        false -> {Cnt, dict:store({KeyNode, MyKey}, Val+Add, WS)}
                    end
                  end, {0, dict:new()}, lists:seq(1, NumKeys)),

            {LocalWriteList, RemoteWriteList} = get_local_remote_writeset(WriteSet, PartList, MyNodeId),
            %lager:warning("Node is ~w, local ws is ~w, remote ws is ~w", [MyNodeId, LocalWriteList, RemoteWriteList]),

            Response = gen_server:call(TxServer, {certify_update, TxId, LocalWriteList, RemoteWriteList, MsgId, SpeculaLen}, ?TIMEOUT),%, length(DepsList)}),
            %lager:warning("After calling certify"),
            case Response of
                {ok, {committed, _CommitTime, Info}} ->
                    {ok, Info, State};
                {ok, {specula_commit, _SpeculaCT, Info}} ->
                    {specula_commit, Info, State};
                {cascade_abort, Info} ->
                    {cascade_abort, Info, State};
                {error,timeout} ->
                    lager:info("Timeout on client ~p",[TxServer]),
                    {error, timeout, State};
                {aborted, Info} ->
                    {aborted, Info, State};
		wrong_msg ->
                    {wrong_msg, State};
                {badrpc, Reason} ->
                    {error, Reason, State}
            end
    end.
    
index(Elem, L) ->
    index(Elem, L, 1).

index(_, [], _) ->
    -1;
index(E, [E|_], N) ->
    N;
index(E, [_|L], N) ->
    index(E, L, N+1).

read_from_node(TxServer, TxId, Key, DcId, MyDcId, PartList, HashDict, SpeculaRead) ->
    {ok, V} = case DcId of
        MyDcId ->
            {_, L} = lists:nth(DcId, PartList),
            %Index = crypto:bytes_to_integer(erlang:md5(Key)) rem length(L) + 1,
            Index = Key rem length(L) + 1,
            Part = lists:nth(Index, L),
            case SpeculaRead of
                ignore ->
                    gen_server:call(TxServer, {read, Key, TxId, Part}, ?READ_TIMEOUT);
                _ ->
                    gen_server:call(TxServer, {read, Key, TxId, Part, SpeculaRead}, ?READ_TIMEOUT)
            end;
        _ ->
            case dict:find(DcId, HashDict) of
                error ->
                    {_, L} = lists:nth(DcId, PartList),
                    %Index = crypto:bytes_to_integer(erlang:md5(Key)) rem length(L) + 1,
                    Index = Key rem length(L) + 1,
                    Part = lists:nth(Index, L),
                    CacheServName = dict:fetch(cache, HashDict),
                    case SpeculaRead of
                        ignore ->
                            gen_server:call(CacheServName, {read, Key, TxId, Part}, ?READ_TIMEOUT);
                        _ ->
                            gen_server:call(CacheServName, {read, Key, TxId, Part, SpeculaRead}, ?READ_TIMEOUT)
                    end;
                {ok, N} ->
                    {_, L} = lists:nth(DcId, PartList),
                    %Index = crypto:bytes_to_integer(erlang:md5(Key)) rem length(L) + 1,
                    Index = Key rem length(L) + 1,
                    Part = lists:nth(Index, L),
                    case SpeculaRead of
                        ignore ->
                            gen_server:call(N, {read, Key, TxId, Part}, ?READ_TIMEOUT);
                        _ ->
                            gen_server:call(N, {read, Key, TxId, Part, SpeculaRead}, ?READ_TIMEOUT)
                    end
            end
    end,
    case V of
        [] ->
        0;
        _ ->
            V
    end.

terminate(_, _State) ->
    ok.

get_local_remote_writeset(WriteSet, PartList, LocalDcId) ->
    {LWSD, RWSD} = dict:fold(fun({NodeId, Key}, Value, {LWS, RWS}) ->
                    case NodeId of LocalDcId -> {add_to_writeset(Key, Value, lists:nth(LocalDcId, PartList), LWS), RWS};
                               _ -> {LWS, add_to_writeset(Key, Value, lists:nth(NodeId, PartList), RWS)}
                    end end, {dict:new(), dict:new()}, WriteSet),
    %L = dict:fetch_keys(RWSD),
    %NodeSet = lists:foldl(fun({_, N}, S) -> sets:add_element(N, S) end, sets:new(), L),
    %ets:update_counter(load_info, TxType, [{2, 1}, {3, length(L)}, {4,sets:size(NodeSet)}]),
    {dict:to_list(LWSD), dict:to_list(RWSD)}.


add_to_writeset(Key, Value, {_, PartList}, WSet) ->
    Index = Key rem length(PartList) + 1,
    Part = lists:nth(Index, PartList),
    dict:append(Part, {Key, Value}, WSet).

%unique_keys(Start, HotRange, UniformRange, NumKeys, HotRate, Nodes) ->
%    unique_keys(Start, HotRange, UniformRange, NumKeys, HotRate, sets:new(), Nodes). 

%unique_keys(_, _, _, 0, _, Set, _) ->
%    sets:to_list(Set);
%unique_keys(Start, HotRange, UniformRange, NumKeys, HotRate, Set, Nodes) ->
%    Key = hot_or_not(Start, HotRange, UniformRange, HotRate), 
%    Node = case Nodes of [_|_] -> L = length(Nodes), Id = random:uniform(L), lists:nth(Id, Nodes);
%                     _ ->  Nodes end,
%    case sets:is_element({Node, Key}, Set) of
%        false -> unique_keys(Start, HotRange, UniformRange, NumKeys-1, HotRate, sets:add_element({Node, Key}, Set), Nodes);
%        true -> 
%                unique_keys(Start, HotRange, UniformRange, NumKeys, HotRate, Set, Nodes)
%    end.

hot_or_not(Start, HotRange, UniformRange, HotRate) ->
      %random:seed(os:timestamp()),
      Rand = random:uniform(100),
      case Rand =< HotRate of
          true -> random:uniform(HotRange) + Start-1;
          false -> random:uniform(UniformRange-HotRange) + Start+HotRange-1
      end.

%unique_num(Base, Num, Range) ->
%    unique_num(Base, Num, Range, sets:new()).

%unique_num(_Base, 0, _Range, Set) ->
%    sets:to_list(Set);
%unique_num(Base, Num, Range, Set) ->
%    N = random:uniform(Range) + Base,
%    case sets:is_element(N, Set) of
%        false -> unique_num(Base, Num-1, Range, sets:add_element(N, Set));
%        true -> unique_num(Base, Num, Range, Set)
%    end.


%get_time_diff({A1, B1, C1}, {A2, B2, C2}) ->
 %   ((A2-A1)*1000000+ (B2-B1))*1000000+ C2-C1.


%local_process(0) ->
%    ok;
%local_process(N) ->
%    StartTime = os:timestamp(),
%    wait_until(StartTime, N*1000).

%wait_until(StartTime, Duration) ->
%    case timer:now_diff(os:timestamp(), StartTime) > Duration of
%        true ->
%            ok;
%        false ->
%            wait_until(StartTime, Duration)
%    end.

%get_time_diff({A1, B1, C1}, {A2, B2, C2}) ->
%    ((A2-A1)*1000000+ (B2-B1))*1000000+ C2-C1.
