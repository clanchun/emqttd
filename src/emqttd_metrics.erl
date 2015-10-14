%%%-----------------------------------------------------------------------------
%%% Copyright (c) 2012-2015 eMQTT.IO, All Rights Reserved.
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in all
%%% copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%%% SOFTWARE.
%%%-----------------------------------------------------------------------------
%%% @doc
%%% emqttd metrics. responsible for collecting broker metrics.
%%%
%%% @end
%%%-----------------------------------------------------------------------------

-module(emqttd_metrics).

-author("Feng Lee <feng@emqtt.io>").

-include("emqttd.hrl").

-include("emqttd_protocol.hrl").

-behaviour(gen_server).

-define(SERVER, ?MODULE).

%% API Function Exports
-export([start_link/0]).

%% Received/Sent Metrics
-export([received/1, sent/1]).

-export([all/0, value/1,
         inc/1, inc/2, inc/3,
         dec/2, dec/3,
         set/2]).

%% gen_server Function Exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {tick_tref}).

-define(METRIC_TAB, mqtt_metric).

%% Bytes sent and received of Broker
-define(SYSTOP_BYTES, [
    {counter, 'bytes/received'},   % Total bytes received
    {counter, 'bytes/sent'}        % Total bytes sent
]).

%% Packets sent and received of Broker
-define(SYSTOP_PACKETS, [
    {counter, 'packets/received'},         % All Packets received
    {counter, 'packets/sent'},             % All Packets sent
    {counter, 'packets/connect'},          % CONNECT Packets received
    {counter, 'packets/connack'},          % CONNACK Packets sent
    {counter, 'packets/publish/received'}, % PUBLISH packets received
    {counter, 'packets/publish/sent'},     % PUBLISH packets sent
    {counter, 'packets/puback/received'},  % PUBACK packets received
    {counter, 'packets/puback/sent'},      % PUBACK packets sent
    {counter, 'packets/pubrec/received'},  % PUBREC packets received
    {counter, 'packets/pubrec/sent'},      % PUBREC packets sent
    {counter, 'packets/pubrel/received'},  % PUBREL packets received
    {counter, 'packets/pubrel/sent'},      % PUBREL packets sent
    {counter, 'packets/pubcomp/received'}, % PUBCOMP packets received
    {counter, 'packets/pubcomp/sent'},     % PUBCOMP packets sent
    {counter, 'packets/subscribe'},        % SUBSCRIBE Packets received 
    {counter, 'packets/suback'},           % SUBACK packets sent 
    {counter, 'packets/unsubscribe'},      % UNSUBSCRIBE Packets received
    {counter, 'packets/unsuback'},         % UNSUBACK Packets sent
    {counter, 'packets/pingreq'},          % PINGREQ packets received
    {counter, 'packets/pingresp'},         % PINGRESP Packets sent
    {counter, 'packets/disconnect'}        % DISCONNECT Packets received 
]).

%% Messages sent and received of broker
-define(SYSTOP_MESSAGES, [
    {counter, 'messages/received'},      % Messages received
    {counter, 'messages/sent'},          % Messages sent
    {counter, 'messages/qos0/received'}, % Messages received
    {counter, 'messages/qos0/sent'},     % Messages sent
    {counter, 'messages/qos1/received'}, % Messages received
    {counter, 'messages/qos1/sent'},     % Messages sent
    {counter, 'messages/qos2/received'}, % Messages received
    {counter, 'messages/qos2/sent'},     % Messages sent
    {gauge,   'messages/retained'},      % Messagea retained
    {counter, 'messages/dropped'}        % Messages dropped
]).

%%%=============================================================================
%%% API
%%%=============================================================================

%%------------------------------------------------------------------------------
%% @doc Start metrics server
%% @end
%%------------------------------------------------------------------------------
-spec start_link() -> {ok, pid()} | ignore | {error, any()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

received(Packet = ?PACKET(Type)) ->
    inc('packets/received'),
    received(Type, Packet).
received(?CONNECT, _Packet) ->
    inc('packets/connect');
received(?PUBLISH, ?PUBLISH(Qos, _PktId)) ->
    inc('packets/publish/received'),
    inc('messages/received'),
    qos_received(Qos);
received(?PUBACK, _Packet) ->  
    inc('packets/puback/received');
received(?PUBREC, _Packet) ->  
    inc('packets/pubrec/received');
received(?PUBREL, _Packet) ->
    inc('packets/pubrel/received');
received(?PUBCOMP, _Packet) ->
    inc('packets/pubcomp/received');
received(?SUBSCRIBE, _Packet) ->
    inc('packets/subscribe');
received(?UNSUBSCRIBE, _Packet) ->
    inc('packets/unsubscribe');
received(?PINGREQ, _Packet) ->
    inc('packets/pingreq');
received(?DISCONNECT, _Packet) ->
    inc('packets/disconnect');
received(_, _) -> ignore.

qos_received(?QOS_0) ->
    inc('messages/qos0/received');
qos_received(?QOS_1) ->
    inc('messages/qos1/received');
qos_received(?QOS_2) ->
    inc('messages/qos2/received').

sent(Packet = ?PACKET(Type)) ->
    emqttd_metrics:inc('packets/sent'),
    sent(Type, Packet).
sent(?CONNACK, _Packet) ->
    inc('packets/connack');
sent(?PUBLISH, ?PUBLISH(Qos, _PktId)) ->
    inc('packets/publish/sent'),
    inc('messages/sent'),
    qos_sent(Qos);
sent(?PUBACK, _Packet) ->
    inc('packets/puback/sent');
sent(?PUBREC, _Packet) ->
    inc('packets/pubrec/sent');
sent(?PUBREL, _Packet) ->
    inc('packets/pubrel/sent');
sent(?PUBCOMP, _Packet) ->
    inc('packets/pubcomp/sent');
sent(?SUBACK, _Packet) ->
    inc('packets/suback');
sent(?UNSUBACK, _Packet) ->
    inc('packets/unsuback');
sent(?PINGRESP, _Packet) ->
    inc('packets/pingresp');
sent(_Type, _Packet) ->
    ingore.

qos_sent(?QOS_0) ->
    inc('messages/qos0/sent');
qos_sent(?QOS_1) ->
    inc('messages/qos1/sent');
qos_sent(?QOS_2) ->
    inc('messages/qos2/sent').

%%------------------------------------------------------------------------------
%% @doc Get all metrics
%% @end
%%------------------------------------------------------------------------------
-spec all() -> [{atom(), non_neg_integer()}].
all() ->
    maps:to_list(
        ets:foldl(
            fun({{Metric, _N}, Val}, Map) ->
                    case maps:find(Metric, Map) of
                        {ok, Count} -> maps:put(Metric, Count+Val, Map);
                        error -> maps:put(Metric, Val, Map)
                    end
            end, #{}, ?METRIC_TAB)).

%%------------------------------------------------------------------------------
%% @doc Get metric value
%% @end
%%------------------------------------------------------------------------------
-spec value(atom()) -> non_neg_integer().
value(Metric) ->
    lists:sum(ets:select(?METRIC_TAB, [{{{Metric, '_'}, '$1'}, [], ['$1']}])).

%%------------------------------------------------------------------------------
%% @doc Increase counter
%% @end
%%------------------------------------------------------------------------------
-spec inc(atom()) -> non_neg_integer().
inc(Metric) ->
    inc(counter, Metric, 1).

%%------------------------------------------------------------------------------
%% @doc Increase metric value
%% @end
%%------------------------------------------------------------------------------
-spec inc(counter | gauge, atom()) -> non_neg_integer().
inc(gauge, Metric) ->
    inc(gauge, Metric, 1);
inc(counter, Metric) ->
    inc(counter, Metric, 1);
inc(Metric, Val) when is_atom(Metric) and is_integer(Val) ->
    inc(counter, Metric, Val).

%%------------------------------------------------------------------------------
%% @doc Increase metric value
%% @end
%%------------------------------------------------------------------------------
-spec inc(counter | gauge, atom(), pos_integer()) -> pos_integer().
inc(gauge, Metric, Val) ->
    ets:update_counter(?METRIC_TAB, key(gauge, Metric), {2, Val});
inc(counter, Metric, Val) ->
    ets:update_counter(?METRIC_TAB, key(counter, Metric), {2, Val}).

%%------------------------------------------------------------------------------
%% @doc Decrease metric value
%% @end
%%------------------------------------------------------------------------------
-spec dec(gauge, atom()) -> integer().
dec(gauge, Metric) ->
    dec(gauge, Metric, 1).

%%------------------------------------------------------------------------------
%% @doc Decrease metric value
%% @end
%%------------------------------------------------------------------------------
-spec dec(gauge, atom(), pos_integer()) -> integer().
dec(gauge, Metric, Val) ->
    ets:update_counter(?METRIC_TAB, key(gauge, Metric), {2, -Val}).

%%------------------------------------------------------------------------------
%% @doc Set metric value
%% @end
%%------------------------------------------------------------------------------
set(Metric, Val) when is_atom(Metric) ->
    set(gauge, Metric, Val).
set(gauge, Metric, Val) ->
    ets:insert(?METRIC_TAB, {key(gauge, Metric), Val}).

%%------------------------------------------------------------------------------
%% @doc Metric Key
%% @end
%%------------------------------------------------------------------------------
key(gauge, Metric) ->
    {Metric, 0};
key(counter, Metric) ->
    {Metric, erlang:system_info(scheduler_id)}.

%%%=============================================================================
%%% gen_server callbacks
%%%=============================================================================

init([]) ->
    random:seed(now()),
    Metrics = ?SYSTOP_BYTES ++ ?SYSTOP_PACKETS ++ ?SYSTOP_MESSAGES,
    % Create metrics table
    ets:new(?METRIC_TAB, [set, public, named_table, {write_concurrency, true}]),
    % Init metrics
    [create_metric(Metric) ||  Metric <- Metrics],
    % $SYS Topics for metrics
    [ok = emqttd_pubsub:create(metric_topic(Topic)) || {_, Topic} <- Metrics],
    % Tick to publish metrics
    {ok, #state{tick_tref = emqttd_broker:start_tick(tick)}, hibernate}.

handle_call(_Req, _From, State) ->
    {reply, error, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, State) ->
    % publish metric message
    [publish(Metric, Val) || {Metric, Val} <- all()],
    {noreply, State, hibernate};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{tick_tref = TRef}) ->
    emqttd_broker:stop_tick(TRef).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%=============================================================================
%%% Internal functions
%%%=============================================================================

publish(Metric, Val) ->
    Payload = emqttd_util:integer_to_binary(Val),
    Msg = emqttd_message:make(metrics, metric_topic(Metric), Payload),
    emqttd_pubsub:publish(emqttd_message:set_flag(sys, Msg)).

create_metric({gauge, Name}) ->
    ets:insert(?METRIC_TAB, {{Name, 0}, 0});

create_metric({counter, Name}) ->
    Schedulers = lists:seq(1, erlang:system_info(schedulers)),
    [ets:insert(?METRIC_TAB, {{Name, I}, 0}) || I <- Schedulers].

metric_topic(Metric) ->
    emqttd_topic:systop(list_to_binary(lists:concat(['metrics/', Metric]))).

